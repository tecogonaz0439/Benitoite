import Benitoite.Release.Refinement.Surface.Check

/-! 案内の大きさによる健全性の帰納で、七つの判断を同時に扱う。 -/
namespace Benitoite.Release.Refinement.Surface.Check

theorem BuilderSupport.extendNone {s Δ} (h : BuilderSupport s Δ) :
    BuilderSupport s (LocalCtx.extend none Δ) := by
  intro i kind hi
  cases i with
  | zero => cases hi
  | succ i =>
    simp only [LocalCtx.extend, List.getElem?_cons_succ, List.getElem?_map] at hi
    cases hd : Δ[i]? with
    | none => simp [hd] at hi
    | some x => cases x with
      | none => simp [hd] at hi
      | some old =>
        simp only [hd, Option.map_some, Option.some.injEq] at hi
        subst kind
        have ho := h i old hd
        cases old <;> try trivial
        case list a =>
          change (renameTy (shiftIndex 1 0) a).Support (· ∈ s)
          rw [← Ty.shiftV_eq_renameTy]
          exact type_shift_support ho 1 0

theorem BuilderSupport.localExtend {s Δ} (h : BuilderSupport s Δ) (k : Nat) :
    BuilderSupport s (localExtend k Δ) := by
  induction k with
  | zero => exact h
  | succ k ih => exact ih.extendNone

theorem _root_.Benitoite.Release.Refinement.Surface.CheckFormation.CtxSupport.shiftTypes {s Γ} (h : CheckFormation.CtxSupport s Γ) (k c : Nat) :
    CheckFormation.CtxSupport s (Γ.shiftEAt k c) := by
  intro i a hi
  simp only [Ctx.shiftEAt, List.getElem?_map] at hi
  cases hg : Γ[i]? with
  | none => simp [hg] at hi
  | some x => cases x with
    | none => simp [hg] at hi
    | some b =>
      simp only [hg, Option.map_some, Option.some.injEq] at hi
      subst a
      exact Ty.rawShift_support _ _ _ (h i b hg)

theorem _root_.Benitoite.Release.Refinement.Surface.CheckFormation.CtxSupport.extendMany {s Γ ps} (h : CheckFormation.CtxSupport s Γ)
    (hp : Ty.SupportList (· ∈ s) ps) : CheckFormation.CtxSupport s (Γ.extendMany ps) := by
  induction ps generalizing Γ with
  | nil => exact h
  | cons a rest ih => exact ih (h.extend hp.1) hp.2

theorem ReturnSupport.shiftTypes {s R} (h : ReturnSupport s R) (k c : Nat) :
    ReturnSupport s (R.map (Refinement.shiftTypes k c)) := by
  cases R with
  | none => trivial
  | some a => exact Ty.rawShift_support _ _ _ h

theorem clause_context_support {s : List Atom} {Γ : Ctx} {sg : OpSig} {a : Ty} {e : Eff} (hΓ : CheckFormation.CtxSupport s Γ)
    (hp : Ty.SupportList (· ∈ s) sg.params) (hr : sg.ret.Support (· ∈ s))
    (ha : a.Support (· ∈ s)) (he : e.Support (· ∈ s)) :
    CheckFormation.CtxSupport s (sg.context Γ a e) := by
  exact ((hΓ.shiftTypes sg.tparams.length 0).extendMany hp).extend
    ⟨hr, type_shift_support (Ty.rawShift_support _ _ _ ha) _ _,
      effect_shift_support (Eff.rawShift_support _ _ _ he) _ _⟩

abbrev ExprSoundAt (g : Guide) : Prop :=
  ∀ {q rows Δ C Γ Φ R p path e a ε}, q.Sound → BuilderSupport q.formation.atoms Δ →
    CheckFormation.CtxSupport q.formation.atoms Γ → ReturnSupport q.formation.atoms R →
    ExprSupport q e → a.Support (· ∈ q.formation.atoms) → ε.Support (· ∈ q.formation.atoms) →
    g.Support q.formation.atoms → checkExprAt q rows Δ C Γ Φ R p path e a ε g = true →
    HasTypeQ q.D q.B q.opPrim (CheckAdmissible.NoFailCtxOf rows) Δ C Γ Φ R p e a ε

abbrev TypesSoundAt (g : Guide) : Prop :=
  ∀ {q rows Δ C Γ Φ R path es as ε}, q.Sound → BuilderSupport q.formation.atoms Δ →
    CheckFormation.CtxSupport q.formation.atoms Γ → ReturnSupport q.formation.atoms R →
    ExprsSupport q es → Ty.SupportList (· ∈ q.formation.atoms) as → ε.Support (· ∈ q.formation.atoms) →
    g.Support q.formation.atoms → checkTypesAt q rows Δ C Γ Φ R path es as ε g = true →
    HasTypesQ q.D q.B q.opPrim (CheckAdmissible.NoFailCtxOf rows) Δ C Γ Φ R es as ε

abbrev EachSoundAt (g : Guide) : Prop :=
  ∀ {q rows Δ C Γ Φ R path es a ε}, q.Sound → BuilderSupport q.formation.atoms Δ →
    CheckFormation.CtxSupport q.formation.atoms Γ → ReturnSupport q.formation.atoms R →
    ExprsSupport q es → a.Support (· ∈ q.formation.atoms) → ε.Support (· ∈ q.formation.atoms) →
    g.Support q.formation.atoms → checkEachAt q rows Δ C Γ Φ R path es a ε g = true →
    HasEachQ q.D q.B q.opPrim (CheckAdmissible.NoFailCtxOf rows) Δ C Γ Φ R es a ε

abbrev FixedSoundAt (g : Guide) : Prop :=
  ∀ {q rows Δ C Γ Φ R path args as ε}, q.Sound → BuilderSupport q.formation.atoms Δ →
    CheckFormation.CtxSupport q.formation.atoms Γ → ReturnSupport q.formation.atoms R →
    HolesSupport q args → Ty.SupportList (· ∈ q.formation.atoms) as → ε.Support (· ∈ q.formation.atoms) →
    g.Support q.formation.atoms → checkFixedAt q rows Δ C Γ Φ R path args as ε g = true →
    HasFixedQ q.D q.B q.opPrim (CheckAdmissible.NoFailCtxOf rows) Δ C Γ Φ R args as ε

abbrev ArmsSoundAt (g : Guide) : Prop :=
  ∀ {q rows Δ C Γ Φ R p path arms a b ε}, q.Sound → BuilderSupport q.formation.atoms Δ →
    CheckFormation.CtxSupport q.formation.atoms Γ → ReturnSupport q.formation.atoms R →
    ArmsSupport q arms → a.Support (· ∈ q.formation.atoms) → b.Support (· ∈ q.formation.atoms) →
    ε.Support (· ∈ q.formation.atoms) → g.Support q.formation.atoms →
    checkArmsAt q rows Δ C Γ Φ R p path arms a b ε g = true →
    HasArmsQ q.D q.B q.opPrim (CheckAdmissible.NoFailCtxOf rows) Δ C Γ Φ R p arms a b ε

abbrev ClausesSoundAt (g : Guide) : Prop :=
  ∀ {q rows Δ C Γ Φ R εbody path cs a ε}, q.Sound → BuilderSupport q.formation.atoms Δ →
    CheckFormation.CtxSupport q.formation.atoms Γ → ReturnSupport q.formation.atoms R →
    ClausesSupport q cs → εbody.Support (· ∈ q.formation.atoms) → a.Support (· ∈ q.formation.atoms) →
    ε.Support (· ∈ q.formation.atoms) → g.Support q.formation.atoms →
    checkClausesAt q rows Δ C Γ Φ R εbody path cs a ε g = true →
    HasClausesQ q.D q.B q.opPrim (CheckAdmissible.NoFailCtxOf rows) Δ C Γ Φ R εbody cs a ε

abbrev BlockSoundAt (g : Guide) : Prop :=
  ∀ {q rows Δ C Γ Φ R p path body a ε}, q.Sound → BuilderSupport q.formation.atoms Δ →
    CheckFormation.CtxSupport q.formation.atoms Γ → ReturnSupport q.formation.atoms R →
    BlockSupport q body → a.Support (· ∈ q.formation.atoms) → ε.Support (· ∈ q.formation.atoms) →
    g.Support q.formation.atoms → checkBlockAt q rows Δ C Γ Φ R p path body a ε g = true →
    HasBlockQ q.D q.B q.opPrim (CheckAdmissible.NoFailCtxOf rows) Δ C Γ Φ R p body a ε

/-- 一つの案内について、相互に参照する全ての判断の健全性。 -/
structure GuideSound (g : Guide) : Prop where
  expr : ExprSoundAt g
  types : TypesSoundAt g
  each : EachSoundAt g
  fixed : FixedSoundAt g
  arms : ArmsSoundAt g
  clauses : ClausesSoundAt g
  block : BlockSoundAt g

/-- 真に小さい案内について使える、七つの判断の帰納仮定。 -/
abbrev SoundBelow (g : Guide) : Prop := ∀ child, sizeOf child < sizeOf g → GuideSound child

end Benitoite.Release.Refinement.Surface.Check
