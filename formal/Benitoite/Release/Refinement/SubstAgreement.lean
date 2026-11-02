import Benitoite.Release.Refinement.LocalTyping
import Benitoite.Release.Refinement.ContextRegularity

/-! # 参照する位置で一致する置換（設計書 01-12「型付け規則」） -/
namespace Benitoite.Release.Refinement
noncomputable section

def SubstAgree (Γ : Ctx) (σ τ : Nat → Val) : Prop :=
  ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → σ i = τ i

def LocalSubstAgree (L : LocalCtx) (ρ η : Nat → LocalRef) : Prop :=
  ∀ (i : Nat) (b : BuilderKind), L[i]? = some (some b) → ρ i = η i

def ObservationAgree (Γ : Ctx) (ν μ : ObservationEnv) : Prop :=
  ∀ i, Γ.Readable i → ν i = μ i

theorem SubstAgree.map {Γ σ τ} (h : SubstAgree Γ σ τ) (f : Ty → Ty) :
    SubstAgree (Γ.map (Option.map f)) σ τ := by
  intro i a hi
  simp only [List.getElem?_map] at hi
  cases hg : Γ[i]? with
  | none => simp [hg] at hi
  | some ob => cases ob with
    | none => simp [hg] at hi
    | some b => exact h i b hg

theorem SubstAgree.hide {Γ σ τ} (h : SubstAgree Γ σ τ) : SubstAgree (hideConts Γ) σ τ :=
  fun i a hi => h i a (hideConts_lookup.mp hi).1

theorem SubstAgree.extendOption {Γ σ τ} (h : SubstAgree Γ σ τ) (x : Option Ty) :
    SubstAgree (x :: Γ.map (Option.map (Ty.shiftV 1 0))) (upSubst 1 σ) (upSubst 1 τ) := by
  intro i a hi
  cases i with
  | zero => rfl
  | succ i =>
    have hh := h.map (Ty.shiftV 1 0) i a (by simpa only [List.getElem?_cons_succ] using hi)
    simp only [upSubst,Nat.succ_lt_succ_iff,Nat.not_lt_zero,↓reduceIte,Nat.add_one_sub_one,hh]

theorem SubstAgree.params {Γ σ τ} (h : SubstAgree Γ σ τ) (ps : List Ty) :
    SubstAgree (bindParams Γ ps) (upSubst ps.length σ) (upSubst ps.length τ) := by
  intro i a hi
  by_cases hn : i < ps.length
  · simp [upSubst,hn]
  · rw [bindParams,List.getElem?_append_right (by simpa using Nat.le_of_not_gt hn)] at hi
    simp only [List.length_map,List.length_reverse] at hi
    have hh := h.map (Ty.shiftV ps.length 0) _ _ hi
    simp only [upSubst,hn,↓reduceIte,hh]

theorem SubstAgree.extendMany {Γ σ τ} (h : SubstAgree Γ σ τ) (ps : List Ty) :
    SubstAgree (Γ.extendMany ps) (upSubst ps.length σ) (upSubst ps.length τ) := by
  induction ps generalizing Γ σ τ with
  | nil => simpa only [Ctx.extendMany,List.length_nil,upSubst_zero] using h
  | cons a ps ih =>
    simpa only [Ctx.extendMany,Ctx.extend,List.length_cons,upSubst_add,Nat.add_comm 1] using
      ih (h.extendOption (some (a.shiftV 1 0)))

theorem SubstAgree.shiftE {Γ σ τ} (h : SubstAgree Γ σ τ) (k : Nat) :
    SubstAgree (Γ.shiftE k) (fun i => (σ i).shiftEAt k 0) (fun i => (τ i).shiftEAt k 0) := by
  intro i a hi
  have hh := h.map (shiftTypes k 0) i a hi
  exact congrArg (Val.shiftEAt k 0) hh

theorem SubstAgree.observation {Γ σ τ} (h : SubstAgree Γ σ τ) :
    ObservationAgree Γ (valEnv σ).values (valEnv τ).values := by
  rintro i ⟨a,hi,ho⟩
  change (σ i).toTerm? = (τ i).toTerm?
  rw [h i a hi]

theorem ObservationAgree.self {Γ ν μ} (h : ObservationAgree Γ ν μ) (a : Ty) :
    ObservationAgree (some a :: Γ) (upValues ν) (upValues μ) := by
  rintro i ⟨b,hi,ho⟩
  cases i with
  | zero => rfl
  | succ i => simp only [upValues,h i ⟨b,hi,ho⟩]

theorem ObservationAgree.extend {Γ ν μ} (h : ObservationAgree Γ ν μ) (a : Ty) :
    ObservationAgree (Γ.extend a) (upValues ν) (upValues μ) := by
  rintro i ⟨b,hi,ho⟩
  cases i with
  | zero => rfl
  | succ i =>
    rw [Ctx.lookup_extend] at hi
    cases hg : Γ[i]? with
    | none => simp [hg] at hi
    | some ob => cases ob with
      | none => simp [hg] at hi
      | some b =>
        simp only [hg,Option.map_some,Option.some.injEq] at hi
        cases hi
        simp only [upValues,h i ⟨_,hg,(Ty.ordinary_shiftV _ _ _).mp ho⟩]

mutual
  theorem Ty.rawSubstV_congr {Γ ν μ a} (h : Ty.References Γ a) (hs : ObservationAgree Γ ν μ) :
      a.rawSubstV ν = a.rawSubstV μ := by
    cases a with
    | base _ | bytes | «opaque» _ _ | «scoped» _ _ _ | pathBases | scopePattern _ | tvar _ | ctor _ => rfl
    | list a | reference a | lazy a | set a | dict _ a =>
      simp only [Ty.rawSubstV,Ty.rawSubstV_congr (a := a) h hs]
    | data d as | external d as | tapp d as => simp only [Ty.rawSubstV,substVTys_congr (as := as) h hs]
    | dependentFn t => simp only [Ty.rawSubstV,Tel.rawSubstV_congr (t := t) h hs]
    | fn ns ps r e => simp only [Ty.rawSubstV,substVTys_congr h.1 hs,Ty.rawSubstV_congr h.2.1 hs,Eff.rawSubstV_congr h.2.2 hs]
    | cont b t e => simp only [Ty.rawSubstV,Ty.rawSubstV_congr h.1 hs,Ty.rawSubstV_congr h.2.1 hs,Eff.rawSubstV_congr h.2.2 hs]
    | map a b => simp only [Ty.rawSubstV,Ty.rawSubstV_congr h.1 hs,Ty.rawSubstV_congr h.2 hs]
    | refined a p =>
      simp only [Ty.rawSubstV,Ty.rawSubstV_congr h.1 hs]
      rw [Pred.bind_congr (Pred.varsIn_mono h.2 (hs.self a))]
  theorem Tel.rawSubstV_congr {Γ ν μ t} (h : Tel.References Γ t) (hs : ObservationAgree Γ ν μ) :
      Tel.rawSubstV ν t = Tel.rawSubstV μ t := by
    cases t with
    | done a e => simp only [Tel.rawSubstV,Ty.rawSubstV_congr h.1 hs,Eff.rawSubstV_congr h.2 hs]
    | param n a t => simp only [Tel.rawSubstV,Ty.rawSubstV_congr h.1 hs,Tel.rawSubstV_congr h.2 (hs.extend a)]
  theorem substVTys_congr {Γ ν μ as} (h : referencesTys Γ as) (hs : ObservationAgree Γ ν μ) :
      substVTys ν as = substVTys μ as := by
    cases as with
    | nil => rfl
    | cons a as => simp only [substVTys,Ty.rawSubstV_congr h.1 hs,substVTys_congr h.2 hs]
  theorem Eff.rawSubstV_congr {Γ ν μ e} (h : Eff.References Γ e) (hs : ObservationAgree Γ ν μ) :
      Eff.rawSubstV ν e = Eff.rawSubstV μ e := by
    cases e with
    | mk atoms fs => simp only [Eff.rawSubstV,substVTys_congr (as := fs) h hs]
end

theorem substTyValues_congr {Γ σ τ a} (h : Ty.References Γ a) (hs : SubstAgree Γ σ τ) :
    substTyValues σ a = substTyValues τ a := by
  simpa only [substTyValues,Ty.bind,valEnv,←Ty.rawSubstV_eq_rawBind] using
    congrArg Ty.norm (Ty.rawSubstV_congr h hs.observation)

theorem substEffValues_congr {Γ σ τ e} (h : Eff.References Γ e) (hs : SubstAgree Γ σ τ) :
    substEffValues σ e = substEffValues τ e := by
  simpa only [substEffValues,Eff.bind,valEnv,←Eff.rawSubstV_eq_rawBind] using
    congrArg Eff.norm (Eff.rawSubstV_congr h hs.observation)

theorem telBindValues_congr {Γ σ τ t} (h : Tel.References Γ t) (hs : SubstAgree Γ σ τ) :
    Tel.bind (valEnv σ) t = Tel.bind (valEnv τ) t := by
  simpa only [Tel.bind,valEnv,←Tel.rawSubstV_eq_rawBind] using
    congrArg Tel.norm (Tel.rawSubstV_congr h hs.observation)

theorem LocalSubstAgree.empty (ρ η : Nat → LocalRef) : LocalSubstAgree [] ρ η := by
  intro i b hi; cases hi

theorem LocalSubstAgree.extend {L ρ η} (h : LocalSubstAgree L ρ η) (x : Option BuilderKind) :
    LocalSubstAgree (LocalCtx.extend x L) (upLocalSubst 1 ρ) (upLocalSubst 1 η) := by
  intro i b hi
  cases i with
  | zero => rfl
  | succ i =>
    simp only [LocalCtx.extend,List.getElem?_cons_succ,List.getElem?_map] at hi
    cases hg : L[i]? with
    | none => simp [hg] at hi
    | some ob => cases ob with
      | none => simp [hg] at hi
      | some b => simp [upLocalSubst,h i b hg]

theorem LocalSubstAgree.localExtend {L ρ η} (h : LocalSubstAgree L ρ η) (n : Nat) :
    LocalSubstAgree (Refinement.localExtend n L) (upLocalSubst n ρ) (upLocalSubst n η) := by
  induction n with
  | zero => simpa only [Refinement.localExtend,upLocalSubst_zero] using h
  | succ n ih => simpa only [Refinement.localExtend,upLocalSubst_add] using ih.extend none

theorem LocalRef.HasKind.subst_congr {Ψ L r b ρ η} (h : LocalRef.HasKind Ψ L r b)
    (hs : LocalSubstAgree L ρ η) : r.subst ρ = r.subst η := by
  induction h with
  | bound hi => exact hs _ _ hi
  | loc hi => rfl
  | normal h ih => exact ih

end
end Benitoite.Release.Refinement
