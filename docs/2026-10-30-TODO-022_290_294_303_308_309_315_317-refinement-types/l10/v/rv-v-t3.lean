import Benitoite.Release.Refinement.ValueFacts
open Benitoite Benitoite.Release.Refinement
namespace RV
/-! 旧の受理: dataInfo が全て none のとき、欄の Annotation/kind だけで VarianceValid が成り立つ。 -/
theorem repl_get {n i : Nat} (h : i < n) : (List.replicate n Variance.invariant)[i]? = some .invariant := by
  simp [List.getElem?_replicate, h]

mutual
  theorem vok_ty {P : Program} (hn : ∀ d, P.dataInfo d = none) {nr n nv} (p : Polarity) :
      (a : Ty) → a.WF nr n nv → a.VarianceOK P (List.replicate n .invariant) p := by
    intro a hw
    cases a <;> simp only [Ty.VarianceOK, Ty.WF] at hw ⊢
    all_goals first | trivial | exact vok_ty hn _ _ hw | skip
    case data d as => exact vok_args hn p as _ (by simp [Program.varianceFor, hn]) hw
    case fn ns ps r e => exact ⟨vok_tys hn _ ps hw.2.1, vok_ty hn p r hw.2.2.1, vok_eff hn _ e hw.2.2.2.1⟩
    case tvar i => exact ⟨.invariant, repl_get hw, trivial⟩
    case cont b t e => exact ⟨vok_ty hn _ b hw.1, vok_ty hn _ t hw.2.1, vok_eff hn _ e hw.2.2.1⟩
    case map a b => exact ⟨vok_ty hn _ a hw.1, vok_ty hn _ b hw.2⟩
    case tapp i as => exact ⟨⟨.invariant, repl_get hw.1, trivial⟩, vok_tys hn _ as hw.2⟩
    case external id as => exact vok_tys hn _ as hw
    case refined a q => exact vok_ty hn p a hw.1
    case dependentFn t => exact vok_tel hn p t hw
  theorem vok_tel {P : Program} (hn : ∀ d, P.dataInfo d = none) {nr n nv} (p : Polarity) :
      (t : Tel) → t.WF nr n nv → t.VarianceOK P (List.replicate n .invariant) p := by
    intro t hw
    cases t with
    | done r e => exact ⟨vok_ty hn p r hw.1, vok_eff hn p e hw.2.1⟩
    | param m a t => exact ⟨vok_ty hn _ a hw.1, vok_tel hn p t hw.2⟩
  theorem vok_eff {P : Program} (hn : ∀ d, P.dataInfo d = none) {nr n nv} (p : Polarity) :
      (e : Eff) → e.WF nr n nv → Eff.VarianceOK P (List.replicate n .invariant) p e := by
    intro e hw
    cases e with
    | mk at' fs => exact vok_tys hn _ fs hw
  theorem vok_tys {P : Program} (hn : ∀ d, P.dataInfo d = none) {nr n nv} (p : Polarity) :
      (as : List Ty) → Ty.WFList nr n nv as → varianceTysOK P (List.replicate n .invariant) p as := by
    intro as hw
    cases as with
    | nil => trivial
    | cons a as => exact ⟨vok_ty hn p a hw.1, vok_tys hn p as hw.2⟩
  theorem vok_args {P : Program} (hn : ∀ d, P.dataInfo d = none) {nr n nv} (p : Polarity) :
      (as : List Ty) → (ws : List Variance) → ws = (List.replicate as.length .invariant) → Ty.WFList nr n nv as →
        varianceArgsOK P (List.replicate n .invariant) p ws as := by
    intro as ws he hw
    cases as with
    | nil => subst he; simp [varianceArgsOK]
    | cons a as =>
      subst he
      simp only [List.length_cons, List.replicate_succ, varianceArgsOK]
      exact ⟨vok_ty hn _ a hw.1, vok_args hn p as _ rfl hw.2⟩
end

theorem legacy_valid {P : Program} (hn : ∀ d, P.dataInfo d = none)
    (hf : ∀ c cd, P.cons c = some cd → ∀ a ∈ cd.args,
      Ty.Annotation P (List.replicate cd.ntys ({} : Benitoite.Release.TParam)) [] a ∧
      Ty.HasKind P (List.replicate cd.ntys .value) a .value) :
    P.VarianceValid := by
  refine ⟨fun d info hi => by simp [hn] at hi, ?_⟩
  intro c cd hc
  refine ⟨fun info hi => by simp [hn] at hi, ?_⟩
  intro a ha
  obtain ⟨h1, h2⟩ := hf c cd hc a ha
  refine ⟨h1, h2, ?_⟩
  have := vok_ty hn (nr := 0) (n := cd.ntys) (nv := 0) .positive a (by simpa using h1.wf)
  simpa [Program.varianceFor, hn] using this
#print axioms legacy_valid
end RV
