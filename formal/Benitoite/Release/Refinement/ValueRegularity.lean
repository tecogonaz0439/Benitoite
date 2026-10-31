import Benitoite.Release.Refinement.OpenSubstitution
import Benitoite.Release.Refinement.ShiftCancellation
import Benitoite.Release.Refinement.DeclaredTransport
import Benitoite.Release.Refinement.ValueClosed
import Benitoite.Release.Refinement.Typing

/-!
# 正規化した値置換の整形式と sort

生の改名の WF 保存は順序を保つ移動に限る。一般の値置換では
型注釈と潜在効果を bind で正規化する。
-/
namespace Benitoite.Release.Refinement

theorem Term.imagesSorted_extend {Γ Δ : Ctx} {ν : ObservationEnv}
    (hs : Term.ImagesSorted Γ Δ ν) (a b : Ty)
    (hb : ∀ s, a.HasSort s → b.HasSort s) :
    Term.ImagesSorted (Γ.extend a) (Δ.extend b) (upValues ν) := by
  intro i t s hi htSort
  cases i with
  | zero =>
    simp only [Ctx.extend, List.getElem?_cons_zero, Option.some.injEq] at hi
    cases hi
    have hs := (Ty.hasSort_shiftV b 1 0 s).mpr (hb s ((Ty.hasSort_shiftV a 1 0 s).mp htSort))
    exact ⟨.var 0, rfl, ⟨b.shiftV 1 0, rfl, hs.ordinary⟩, b.shiftV 1 0, rfl, hs⟩
  | succ i =>
    simp only [Ctx.extend, List.getElem?_cons_succ, List.getElem?_map] at hi
    cases hg : Γ[i]? with
    | none => simp [hg] at hi
    | some u =>
      cases u with
      | none => simp [hg] at hi
      | some u =>
        simp only [hg, Option.map_some, Option.some.injEq] at hi
        cases hi
        obtain ⟨v, hv, hs⟩ := hs i u s hg ((Ty.hasSort_shiftV _ _ _ _).mp htSort)
        exact ⟨_, by simp only [upValues, hv, Option.map_some],
          Term.hasSort_lift (Term.hasSort_map_shiftV hs 1 0) _⟩

theorem Term.imageReferences_extend {Γ Δ : Ctx} {ν : ObservationEnv}
    (hr : Term.ImageReferences Γ Δ ν) (a b : Ty) (ho : Ordinary a → Ordinary b) :
    Term.ImageReferences (Γ.extend a) (Δ.extend b) (upValues ν) := by
  intro i t hi htOrd v hv
  cases i with
  | zero =>
    simp only [Ctx.extend, List.getElem?_cons_zero, Option.some.injEq] at hi
    cases hi
    cases hv
    exact ⟨b.shiftV 1 0, rfl, (Ty.ordinary_shiftV _ _ _).mpr (ho ((Ty.ordinary_shiftV _ _ _).mp htOrd))⟩
  | succ i =>
    simp only [Ctx.extend, List.getElem?_cons_succ, List.getElem?_map] at hi
    cases hg : Γ[i]? with
    | none => simp [hg] at hi
    | some u =>
      cases u with
      | none => simp [hg] at hi
      | some u =>
        simp only [hg, Option.map_some, Option.some.injEq] at hi
        cases hi
        simp only [upValues, Option.map_eq_some_iff] at hv
        obtain ⟨w, hw, rfl⟩ := hv
        exact Term.references_lift (Term.references_map_shiftV
          (hr i u hg ((Ty.ordinary_shiftV _ _ _).mp htOrd) w hw) 1 0) _

theorem Pred.wf_of_sorted {Γ a p} (h : Pred.Sorted Γ (some a) p) : p.WF (Γ.length+1) := by
  exact Pred.references_wf h.references

mutual
  theorem Ty.sorted_rawSubstV {Γ Δ a} (h : Ty.Sorted Γ a) (σ : ObservationEnv)
      (hs : Term.ImagesSorted Γ Δ σ) (hr : Term.ImageReferences Γ Δ σ) :
      (a.rawSubstV σ).Sorted Δ := by
    cases a <;> simp only [Ty.Sorted] at h <;> simp only [Ty.rawSubstV, Ty.Sorted]
    all_goals first | trivial | exact Ty.sorted_rawSubstV h σ hs hr | exact sortedTys_rawSubstV h σ hs hr | exact Tel.sorted_rawSubstV h σ hs hr | skip
    case fn ns ps r e => exact ⟨sortedTys_rawSubstV h.1 σ hs hr,
      Ty.sorted_rawSubstV h.2.1 σ hs hr, sortedEff_rawSubstV h.2.2 σ hs hr⟩
    case cont b t e => exact ⟨Ty.sorted_rawSubstV h.1 σ hs hr,
      Ty.sorted_rawSubstV h.2.1 σ hs hr, sortedEff_rawSubstV h.2.2 σ hs hr⟩
    case map a b => exact ⟨Ty.sorted_rawSubstV h.1 σ hs hr, Ty.sorted_rawSubstV h.2 σ hs hr⟩
    case refined a p => exact ⟨Ty.sorted_rawSubstV h.1 σ hs hr,
      Pred.sorted_bind h.2 σ (fun sort hi => (Ty.hasSort_rawSubstV _ _ sort).mpr hi)
        (fun hi => (Ty.ordinary_rawSubstV _ _).mpr hi) hs hr⟩
  theorem Tel.sorted_rawSubstV {Γ Δ t} (h : Tel.Sorted Γ t) (σ : ObservationEnv)
      (hs : Term.ImagesSorted Γ Δ σ) (hr : Term.ImageReferences Γ Δ σ) :
      Tel.Sorted Δ (Tel.rawSubstV σ t) := by
    cases t with
    | done r e => exact ⟨Ty.sorted_rawSubstV h.1 σ hs hr, sortedEff_rawSubstV h.2 σ hs hr⟩
    | param n a t => exact ⟨Ty.sorted_rawSubstV h.1 σ hs hr,
        Tel.sorted_rawSubstV h.2 (upValues σ)
          (Term.imagesSorted_extend hs a (a.rawSubstV σ) (fun s h => (Ty.hasSort_rawSubstV _ _ _).mpr h))
          (Term.imageReferences_extend hr a (a.rawSubstV σ) (fun h => (Ty.ordinary_rawSubstV _ _).mpr h))⟩
  theorem sortedTys_rawSubstV {Γ Δ as} (h : sortedTys Γ as) (σ : ObservationEnv)
      (hs : Term.ImagesSorted Γ Δ σ) (hr : Term.ImageReferences Γ Δ σ) :
      sortedTys Δ (substVTys σ as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.sorted_rawSubstV h.1 σ hs hr, sortedTys_rawSubstV h.2 σ hs hr⟩
  theorem sortedEff_rawSubstV {Γ Δ e} (h : sortedEff Γ e) (σ : ObservationEnv)
      (hs : Term.ImagesSorted Γ Δ σ) (hr : Term.ImageReferences Γ Δ σ) :
      sortedEff Δ (Eff.rawSubstV σ e) := by
    cases e; exact sortedTys_rawSubstV h σ hs hr
end

private theorem sortedTys_iff {Γ as} : sortedTys Γ as ↔ ∀ a ∈ as, a.Sorted Γ := by
  induction as with
  | nil => simp [sortedTys]
  | cons a as ih => simp only [sortedTys, ih, List.mem_cons, forall_eq_or_imp]

private def sortWitness : «Sort» → Term
  | .integer => .integer 0
  | .character => .character 'a'
  | .float64 => .float64 0
  | .float32 => .float32 0
  | .decimal => .decimal 0 0
  | .boolean => .boolean false
  | .unit => .unitValue
  | .string => .string ""
  | .list => .listValue []
  | .bytes => .bytesValue []
  | .map => .mapValue [] []
  | .set => .setValue []
  | .data => .dataValue "" []
  | .target .path => .targetValue none (.path [])
  | .target .host => .targetValue none (.host (.name []))
  | .target .endpoint => .targetValue none (.endpoint ⟨.name [], 0⟩)

private theorem sortWitness_sorted (Γ : Ctx) (s : «Sort») : (sortWitness s).HasSort Γ s := by
  cases s <;> try exact ⟨trivial, rfl⟩
  case target k => cases k <;> exact ⟨trivial, rfl⟩
  case map => exact ⟨⟨trivial, trivial⟩, rfl⟩

private theorem dropWitness (Γ : Ctx) (a : Ty) :
    ∃ t : Term, t.References Γ ∧ ∀ s, a.HasSort s → t.HasSort Γ s := by
  cases he : a.sort? with
  | none =>
    refine ⟨.unitValue, trivial, ?_⟩
    intro s hs; change a.sort? = some s at hs; rw [he] at hs; cases hs
  | some s =>
    refine ⟨sortWitness s, (sortWitness_sorted Γ s).1, ?_⟩
    intro r hr
    cases Option.some.inj (he.symm.trans hr)
    exact sortWitness_sorted Γ s

theorem Term.drop_images {Γ : Ctx} {a : Ty} {t : Term} (ht : t.References Γ)
    (hs : ∀ s, a.HasSort s → t.HasSort Γ s) :
    Term.ImagesSorted (Γ.extend a) Γ (dropValue t) ∧
      Term.ImageReferences (Γ.extend a) Γ (dropValue t) := by
  constructor
  · intro i b s hi hb
    cases i with
    | zero =>
      cases Option.some.inj hi
      exact ⟨t, rfl, hs s ((Ty.hasSort_shiftV _ _ _ _).mp hb)⟩
    | succ i =>
      simp only [Ctx.extend, List.getElem?_cons_succ, List.getElem?_map] at hi
      obtain ⟨ob, hob, ho⟩ := Option.map_eq_some_iff.mp hi
      cases ob with
      | none => cases ho
      | some b =>
        cases ho
        exact ⟨.var i, rfl, ⟨b, hob, ((Ty.hasSort_shiftV _ _ _ _).mp hb).ordinary⟩,
          b, hob, (Ty.hasSort_shiftV _ _ _ _).mp hb⟩
  · intro i b hi hb u hu
    cases i with
    | zero => cases hu; exact ht
    | succ i =>
      cases hu
      simp only [Ctx.extend, List.getElem?_cons_succ, List.getElem?_map] at hi
      obtain ⟨ob, hob, ho⟩ := Option.map_eq_some_iff.mp hi
      cases ob with
      | none => cases ho
      | some b => cases ho; exact ⟨b, hob, (Ty.ordinary_shiftV _ _ _).mp hb⟩

theorem Term.drop_reference_images (Γ : Ctx) (b : Ty) :
    ∃ t : Term, Term.ImageReferences (Γ.extend b) Γ (dropValue t) := by
  obtain ⟨t, ht, hs⟩ := dropWitness Γ b
  exact ⟨t, (Term.drop_images ht hs).2⟩

theorem Ty.sorted_shiftV_rev {Γ : Ctx} {a b : Ty} (h : (a.shiftV 1 0).Sorted (Γ.extend b)) : a.Sorted Γ := by
  obtain ⟨t, ht, hs⟩ := dropWitness Γ b
  have hh := Ty.sorted_rawSubstV h (dropValue t) (Term.drop_images ht hs).1 (Term.drop_images ht hs).2
  rwa [Ty.substV_shift_cancel _ (dropValue_shift t)] at hh

theorem sortedTys_shiftV_rev {Γ : Ctx} {as : List Ty} {b : Ty} (h : sortedTys (Γ.extend b) (shiftVTys 1 0 as)) : sortedTys Γ as := by
  cases as with
  | nil => trivial
  | cons a as => exact ⟨Ty.sorted_shiftV_rev h.1, sortedTys_shiftV_rev h.2⟩

theorem sortedEff_shiftV_rev {Γ : Ctx} {e : Eff} {b : Ty} (h : sortedEff (Γ.extend b) (e.shiftV 1 0)) : sortedEff Γ e := by
  cases e; exact sortedTys_shiftV_rev h

theorem Ty.sorted_of_toTel {Γ ns ps r e} (hn : NamesWF ns ps)
    (h : Tel.Sorted Γ (Ty.toTel ns ps r e)) : (Ty.fn ns ps r e).Sorted Γ := by
  induction ns generalizing Γ ps r e with
  | nil => cases ps with
    | nil => exact ⟨trivial, h⟩
    | cons => simp [NamesWF] at hn
  | cons n ns ih => cases ps with
    | nil => simp [NamesWF] at hn
    | cons a ps =>
      have hn' : NamesWF ns (shiftVTys 1 0 ps) :=
        ⟨by simpa [NamesWF] using Nat.succ.inj hn.1, hn.2.of_cons⟩
      have hh := ih hn' h.2
      exact ⟨⟨h.1, sortedTys_shiftV_rev hh.1⟩, Ty.sorted_shiftV_rev hh.2.1, sortedEff_shiftV_rev hh.2.2⟩

theorem Ty.sorted_foldFn {Γ t} (h : Tel.Sorted Γ t) : (Ty.foldFn t).Sorted Γ := by
  classical
  by_cases he : ∃ f : FnView, f.toTel = t
  · obtain ⟨f, rfl⟩ := he
    rw [Ty.foldFn_toTel]
    exact Ty.sorted_of_toTel f.names_wf h
  · rw [Ty.foldFn_no_view he]; exact h

theorem Pred.sorted_conjuncts {Γ : Ctx} {self : Option Ty} {p : Pred} (h : p.Sorted Γ self) : ∀ q : Pred, q ∈ p.conjuncts → q.Sorted Γ self := by
  cases p with
  | truth => intro q hq; cases hq
  | and p q =>
    intro r hr
    rcases List.mem_append.mp hr with hr | hr
    · exact Pred.sorted_conjuncts h.1 r hr
    · exact Pred.sorted_conjuncts h.2 r hr
  | _ => intro q hq; cases List.mem_singleton.mp hq; exact h

theorem Pred.sorted_ofConjuncts {Γ : Ctx} {self : Option Ty} {ps : List Pred} (h : ∀ p ∈ ps, p.Sorted Γ self) :
    (Pred.ofConjuncts ps).Sorted Γ self := by
  induction ps with
  | nil => trivial
  | cons p ps ih => cases ps with
    | nil => exact h p List.mem_cons_self
    | cons q qs => exact ⟨h p List.mem_cons_self, ih (fun r hr => h r (List.mem_cons_of_mem p hr))⟩

private theorem sorted_coreSelf {Γ : Ctx} {a : Ty} {p : Pred} (h : p.Sorted Γ (some a)) : p.Sorted Γ (some a.core) := by
  simpa only [upValues_id, predBind_id] using
    Pred.sorted_bind h (fun i => some (.var i))
      (fun s hs => by
        have he : a.core.sort? = a.sort? := Ty.sort?_core a
        exact he.trans hs)
      (fun ho => by simpa only [Ordinary, Ty.core_idem] using ho)
      (Transport.id Γ []).values (Transport.id Γ []).references

theorem Ty.Sorted.core {Γ : Ctx} {a : Ty} (h : a.Sorted Γ) : a.core.Sorted Γ := by
  cases a with
  | refined a p => exact Ty.Sorted.core (a := a) h.1
  | _ => exact h

theorem Ty.Sorted.predicates {Γ : Ctx} {a : Ty} (h : a.Sorted Γ) :
    ∀ p : Pred, p ∈ a.refinementPredicates → p.Sorted Γ (some a.core) := by
  cases a with
  | refined a p =>
    intro q hq
    rcases List.mem_append.mp hq with hq | hq
    · exact Ty.Sorted.predicates (a := a) h.1 q hq
    · exact Pred.sorted_conjuncts (sorted_coreSelf h.2) q hq
  | _ => intro p hp; cases hp

theorem Ty.sorted_refineNorm {Γ : Ctx} {a : Ty} {p : Pred} (ha : a.Sorted Γ) (hp : p.Sorted Γ (some a)) :
    (a.refineNorm p).Sorted Γ := by
  unfold Ty.refineNorm
  cases he : a.refinementPredicates ++ p.conjuncts with
  | nil => exact ha.core
  | cons q qs =>
    refine ⟨ha.core, Pred.sorted_ofConjuncts ?_⟩
    intro r hr
    rw [←he] at hr
    rcases List.mem_append.mp hr with hr | hr
    · exact ha.predicates r hr
    · exact Pred.sorted_conjuncts (sorted_coreSelf hp) r hr

mutual
  theorem Ty.sorted_norm {Γ a} (h : Ty.Sorted Γ a) : a.norm.Sorted Γ := by
    cases a <;> simp only [Ty.Sorted] at h <;> simp only [Ty.norm, Ty.Sorted]
    all_goals first | trivial | exact Ty.sorted_norm h | exact sortedTys_norm h | exact Tel.sorted_norm h | skip
    case fn ns ps r e => exact ⟨sortedTys_norm h.1, Ty.sorted_norm h.2.1, sortedEff_norm h.2.2⟩
    case cont b t e => exact ⟨Ty.sorted_norm h.1, Ty.sorted_norm h.2.1, sortedEff_norm h.2.2⟩
    case map a b => exact ⟨Ty.sorted_norm h.1, Ty.sorted_norm h.2⟩
    case dependentFn t => exact Ty.sorted_foldFn (Tel.sorted_norm h)
    case refined a p =>
      apply Ty.sorted_refineNorm (Ty.sorted_norm h.1)
      simpa only [upValues_id, predBind_id] using
        Pred.sorted_bind h.2 (fun i => some (.var i))
          (fun sort hi => (Ty.hasSort_norm _ sort).mpr hi)
          (fun hi => (Ty.ordinary_norm _).mpr hi)
          (Transport.id Γ []).values (Transport.id Γ []).references
  theorem Tel.sorted_norm {Γ t} (h : Tel.Sorted Γ t) : Tel.Sorted Γ (Tel.norm t) := by
    cases t with
    | done r e => exact ⟨Ty.sorted_norm h.1, sortedEff_norm h.2⟩
    | param n a t => exact ⟨Ty.sorted_norm h.1, Tel.Sorted.context (Tel.sorted_norm h.2)
        ((Ctx.TypeMap.id Γ).extend a a.norm (fun s h => (Ty.hasSort_norm _ _).mpr h)
          (fun h => (Ty.ordinary_norm _).mpr h) (by simp only [Ty.assume_norm]; exact fun _ h => h))⟩
  theorem sortedTys_norm {Γ as} (h : sortedTys Γ as) : sortedTys Γ (Ty.normTys as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.sorted_norm h.1, sortedTys_norm h.2⟩
  theorem sortedEff_norm {Γ e} (h : sortedEff Γ e) : sortedEff Γ e.norm := by
    cases e with
    | mk a fs =>
      exact sortedTys_iff.mpr (fun t ht => sortedTys_iff.mp (sortedTys_norm h) t
        (Order.mem_sortUnique.mp ht))
end

mutual
  /-- 参照の上限と篩の芯を検査する。潜在効果の整列は正規化で回復する。 -/
  private def Bounds (nr nt nv : Nat) : Ty → Prop
    | .base _ | .bytes | .ctor _ | .pathBases | .scopePattern _ => True
    | .opaque _ ix | .scoped _ _ ix => ix.WF nr
    | .data _ as | .external _ as => BoundsList nr nt nv as
    | .list a | .reference a | .lazy a | .set a | .dict _ a => Bounds nr nt nv a
    | .fn ns ps r e => NamesWF ns ps ∧ BoundsList nr nt nv ps ∧ Bounds nr nt nv r ∧ BoundsEff nr nt nv e
    | .tvar i => i < nt
    | .cont b t e => Bounds nr nt nv b ∧ Bounds nr nt nv t ∧ BoundsEff nr nt nv e
    | .map a b => Bounds nr nt nv a ∧ Bounds nr nt nv b
    | .tapp i as => i < nt ∧ BoundsList nr nt nv as
    | .refined a p => Bounds nr nt nv a ∧ p.WF (nv+1) ∧ a.NotContCore
    | .dependentFn t => BoundsTel nr nt nv t
  private def BoundsTel (nr nt nv : Nat) : Tel → Prop
    | .done r e => Bounds nr nt nv r ∧ BoundsEff nr nt nv e
    | .param _ a t => Bounds nr nt nv a ∧ BoundsTel nr nt (nv+1) t
  private def BoundsList (nr nt nv : Nat) : List Ty → Prop
    | [] => True
    | a :: as => Bounds nr nt nv a ∧ BoundsList nr nt nv as
  private def BoundsEff (nr nt nv : Nat) : Eff → Prop
    | .mk _ fs => BoundsList nr nt nv fs
end

mutual
  private theorem bounds_of_wf {nr nt nv a} (h : Ty.WF nr nt nv a) : Bounds nr nt nv a := by
    cases a <;> simp only [Ty.WF] at h <;> simp only [Bounds]
    all_goals first | exact h | exact bounds_of_wf h | exact boundsList_of_wf h | exact boundsTel_of_wf h | skip
    case fn ns ps r e => exact ⟨h.1, boundsList_of_wf h.2.1, bounds_of_wf h.2.2.1, boundsEff_of_wf h.2.2.2.1⟩
    case cont b t e => exact ⟨bounds_of_wf h.1, bounds_of_wf h.2.1, boundsEff_of_wf h.2.2.1⟩
    case map a b => exact ⟨bounds_of_wf h.1, bounds_of_wf h.2⟩
    case tapp i as => exact ⟨h.1, boundsList_of_wf h.2⟩
    case refined a p => exact ⟨bounds_of_wf h.1, h.2⟩
  private theorem boundsTel_of_wf {nr nt nv t} (h : Tel.WF nr nt nv t) : BoundsTel nr nt nv t := by
    cases t with
    | done r e => exact ⟨bounds_of_wf h.1, boundsEff_of_wf h.2.1⟩
    | param n a t => exact ⟨bounds_of_wf h.1, boundsTel_of_wf h.2⟩
  private theorem boundsList_of_wf {nr nt nv as} (h : Ty.WFList nr nt nv as) : BoundsList nr nt nv as := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨bounds_of_wf h.1, boundsList_of_wf h.2⟩
  private theorem boundsEff_of_wf {nr nt nv e} (h : Eff.WF nr nt nv e) : BoundsEff nr nt nv e := by
    cases e; exact boundsList_of_wf h
end

private theorem boundsList_iff {nr nt nv as} :
    BoundsList nr nt nv as ↔ ∀ a ∈ as, Bounds nr nt nv a := by
  induction as with
  | nil => simp [BoundsList]
  | cons a as ih => simp only [BoundsList, ih, List.mem_cons, forall_eq_or_imp]

mutual
  private theorem wf_norm_of_bounds {nr nt nv a} (h : Bounds nr nt nv a) : a.norm.WF nr nt nv := by
    cases a <;> simp only [Bounds] at h <;> simp only [Ty.norm, Ty.WF]
    all_goals first | exact h | exact wf_norm_of_bounds h | exact wfList_norm_of_bounds h | exact wfTel_norm_of_bounds h | skip
    case fn ns ps r e => exact ⟨by simpa [NamesWF] using h.1,
      wfList_norm_of_bounds h.2.1, wf_norm_of_bounds h.2.2.1, wfEff_norm_of_bounds h.2.2.2, Eff.norm_idem _⟩
    case cont b t e => exact ⟨wf_norm_of_bounds h.1, wf_norm_of_bounds h.2.1, wfEff_norm_of_bounds h.2.2, Eff.norm_idem _⟩
    case map a b => exact ⟨wf_norm_of_bounds h.1, wf_norm_of_bounds h.2⟩
    case tapp i as => exact ⟨h.1, wfList_norm_of_bounds h.2⟩
    case refined a p => exact Ty.wf_refineNorm (wf_norm_of_bounds h.1) h.2.1 ((Ty.notContCore_norm _).mpr h.2.2)
    case dependentFn t => exact Ty.wf_foldFn (wfTel_norm_of_bounds h)
  private theorem wfTel_norm_of_bounds {nr nt nv t} (h : BoundsTel nr nt nv t) : Tel.WF nr nt nv (Tel.norm t) := by
    cases t with
    | done r e => exact ⟨wf_norm_of_bounds h.1, wfEff_norm_of_bounds h.2, Eff.norm_idem e⟩
    | param n a t => exact ⟨wf_norm_of_bounds h.1, wfTel_norm_of_bounds h.2⟩
  private theorem wfList_norm_of_bounds {nr nt nv as} (h : BoundsList nr nt nv as) :
      Ty.WFList nr nt nv (Ty.normTys as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨wf_norm_of_bounds h.1, wfList_norm_of_bounds h.2⟩
  private theorem wfEff_norm_of_bounds {nr nt nv e} (h : BoundsEff nr nt nv e) : e.norm.WF nr nt nv := by
    cases e with
    | mk a fs => exact Ty.wfList_iff.mpr (fun t ht => Ty.wfList_iff.mp
        (wfList_norm_of_bounds h) t (Order.mem_sortUnique.mp ht))
end

theorem Term.imageWF_extend {Γ Δ : Ctx} {ν : ObservationEnv} (hs : Term.ImageWF Γ Δ ν)
    (a b : Ty) : Term.ImageWF (Γ.extend a) (Δ.extend b) (upValues ν) := by
  intro i t hi ho v hv
  cases i with
  | zero => cases hv; simp [termWF, Term.VarsIn, Ctx.extend]
  | succ i =>
    simp only [Ctx.extend, List.getElem?_cons_succ, List.getElem?_map] at hi
    cases hg : Γ[i]? with
    | none => simp [hg] at hi
    | some u => cases u with
      | none => simp [hg] at hi
      | some u =>
        simp only [hg, Option.map_some, Option.some.injEq] at hi
        cases hi
        simp only [upValues, Option.map_eq_some_iff] at hv
        obtain ⟨w, hw, rfl⟩ := hv
        have hh := hs i u hg ((Ty.ordinary_shiftV _ _ _).mp ho) w hw
        apply termWF_bind hh
        intro j hj z hz
        cases hz
        simpa [Ctx.extend, termWF, Term.VarsIn] using Nat.succ_lt_succ hj

mutual
  private theorem bounds_subst {nr nt Γ Δ a} (h : Bounds nr nt Γ.length a) (ha : a.References Γ)
      (σ : ObservationEnv)
      (hs : Term.ImageWF Γ Δ σ) :
      Bounds nr nt Δ.length (a.rawSubstV σ) := by
    cases a <;> simp only [Bounds] at h <;> simp only [Ty.References] at ha <;> simp only [Ty.rawSubstV, Bounds]
    all_goals first | exact h | exact bounds_subst h ha σ hs | exact boundsList_subst h ha σ hs | exact boundsTel_subst h ha σ hs | skip
    case fn ns ps r e => exact ⟨by simpa [NamesWF] using h.1,
      boundsList_subst h.2.1 ha.1 σ hs, bounds_subst h.2.2.1 ha.2.1 σ hs,
      boundsEff_subst h.2.2.2 ha.2.2 σ hs⟩
    case cont b t e => exact ⟨bounds_subst h.1 ha.1 σ hs, bounds_subst h.2.1 ha.2.1 σ hs,
      boundsEff_subst h.2.2 ha.2.2 σ hs⟩
    case map a b => exact ⟨bounds_subst h.1 ha.1 σ hs, bounds_subst h.2 ha.2 σ hs⟩
    case tapp i as => exact ⟨h.1, boundsList_subst h.2 ha σ hs⟩
    case refined a p => exact ⟨bounds_subst h.1 ha.1 σ hs,
      Pred.wf_bind_references (b := a.rawSubstV σ) ha.2 σ hs,
      (Ty.notContCore_rawSubstV _ _).mpr h.2.2⟩
  private theorem boundsTel_subst {nr nt Γ Δ t} (h : BoundsTel nr nt Γ.length t) (ha : Tel.References Γ t)
      (σ : ObservationEnv) (hs : Term.ImageWF Γ Δ σ) : BoundsTel nr nt Δ.length (Tel.rawSubstV σ t) := by
    cases t with
    | done r e => exact ⟨bounds_subst h.1 ha.1 σ hs, boundsEff_subst h.2 ha.2 σ hs⟩
    | param n a t =>
      refine ⟨bounds_subst h.1 ha.1 σ hs, ?_⟩
      have hh := boundsTel_subst (Γ := Γ.extend a) (Δ := Δ.extend (a.rawSubstV σ))
        (by simpa [Ctx.extend] using h.2) ha.2 (upValues σ) (Term.imageWF_extend hs a (a.rawSubstV σ))
      simpa [Ctx.extend] using hh
  private theorem boundsList_subst {nr nt Γ Δ as} (h : BoundsList nr nt Γ.length as) (ha : referencesTys Γ as)
      (σ : ObservationEnv)
      (hs : Term.ImageWF Γ Δ σ) :
      BoundsList nr nt Δ.length (substVTys σ as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨bounds_subst h.1 ha.1 σ hs, boundsList_subst h.2 ha.2 σ hs⟩
  private theorem boundsEff_subst {nr nt Γ Δ e} (h : BoundsEff nr nt Γ.length e) (ha : Eff.References Γ e)
      (σ : ObservationEnv)
      (hs : Term.ImageWF Γ Δ σ) :
      BoundsEff nr nt Δ.length (Eff.rawSubstV σ e) := by
    cases e; exact boundsList_subst h ha σ hs
end

theorem Ty.wf_bind_values {nr nt Γ Δ a} (h : Ty.WF nr nt Γ.length a) (ha : a.References Γ)
    (σ : ObservationEnv)
    (hs : Term.ImageWF Γ Δ σ) :
    (a.bind (SubstEnv.valuesOnly σ)).WF nr nt Δ.length := by
  change (a.rawBind _).norm.WF nr nt Δ.length
  unfold SubstEnv.valuesOnly
  rw [← Ty.rawSubstV_eq_rawBind]
  exact wf_norm_of_bounds (bounds_subst (bounds_of_wf h) ha σ hs)

theorem Ty.sorted_bind_values {Γ Δ : Ctx} {a : Ty} (ha : a.Sorted Γ) (σ : ObservationEnv)
    (hs : Term.ImagesSorted Γ Δ σ) (hr : Term.ImageReferences Γ Δ σ) :
    (a.bind (SubstEnv.valuesOnly σ)).Sorted Δ := by
  change (a.rawBind _).norm.Sorted Δ
  unfold SubstEnv.valuesOnly
  rw [← Ty.rawSubstV_eq_rawBind]
  exact Ty.sorted_norm (Ty.sorted_rawSubstV ha σ hs hr)

theorem Eff.wf_bind_values {nr nt Γ Δ e} (h : Eff.WF nr nt Γ.length e) (ha : Eff.References Γ e)
    (σ : ObservationEnv)
    (hs : Term.ImageWF Γ Δ σ) :
    (Eff.bind (SubstEnv.valuesOnly σ) e).WF nr nt Δ.length := by
  change (Eff.rawBind _ e).norm.WF nr nt Δ.length
  unfold SubstEnv.valuesOnly
  rw [← Eff.rawSubstV_eq_rawBind]
  exact wfEff_norm_of_bounds (boundsEff_subst (boundsEff_of_wf h) ha σ hs)

theorem Eff.sorted_bind_values {Γ Δ e} (ha : sortedEff Γ e) (σ : ObservationEnv)
    (hs : Term.ImagesSorted Γ Δ σ) (hr : Term.ImageReferences Γ Δ σ) :
    sortedEff Δ (Eff.bind (SubstEnv.valuesOnly σ) e) := by
  change sortedEff Δ (Eff.rawBind _ e).norm
  unfold SubstEnv.valuesOnly
  rw [← Eff.rawSubstV_eq_rawBind]
  exact sortedEff_norm (sortedEff_rawSubstV ha σ hs hr)

theorem Tel.wf_bind_values {nr nt Γ Δ t} (h : Tel.WF nr nt Γ.length t) (ha : Tel.References Γ t)
    (σ : ObservationEnv) (hs : Term.ImageWF Γ Δ σ) :
    Tel.WF nr nt Δ.length (Tel.bind (SubstEnv.valuesOnly σ) t) := by
  change Tel.WF nr nt Δ.length (Tel.norm (Tel.rawBind _ t))
  unfold SubstEnv.valuesOnly
  rw [← Tel.rawSubstV_eq_rawBind]
  exact wfTel_norm_of_bounds (boundsTel_subst (boundsTel_of_wf h) ha σ hs)

theorem Tel.sorted_bind_values {Γ Δ t} (h : Tel.Sorted Γ t) (σ : ObservationEnv)
    (hs : Term.ImagesSorted Γ Δ σ) (hr : Term.ImageReferences Γ Δ σ) :
    Tel.Sorted Δ (Tel.bind (SubstEnv.valuesOnly σ) t) := by
  change Tel.Sorted Δ (Tel.norm (Tel.rawBind _ t))
  unfold SubstEnv.valuesOnly
  rw [← Tel.rawSubstV_eq_rawBind]
  exact Tel.sorted_norm (Tel.sorted_rawSubstV h σ hs hr)

/-- WFな文脈では、芯での継続の非表示は従来の最外での非表示と一致する。 -/
theorem hideConts_of_wf {Γ nr nt} (h : Ctx.WF nr nt Γ) :
    hideConts Γ = Γ.map (fun a => match a with | some (.cont _ _ _) => none | a => a) := by
  apply List.map_congr_left
  intro oa hm
  cases oa with
  | none => rfl
  | some a =>
    obtain ⟨i, hi⟩ := List.mem_iff_getElem?.mp hm
    have hw := h i a hi
    cases a <;> try rfl
    case refined a p =>
      change (match a.core with | .cont _ _ _ => none | _ => some (Ty.refined a p)) = some (Ty.refined a p)
      cases hc : a.core <;> try rfl
      exact False.elim (hw.2.2 _ _ _ hc)

end Benitoite.Release.Refinement
