import Benitoite.Release.Refinement.Surface.CheckSoundBase
import Benitoite.Release.Refinement.Surface.CheckOpen

namespace Benitoite.Release.Refinement.Surface.CheckOpen
open Check
open Check

abbrev ExprSoundAt (g : Guide) : Prop :=
  ∀ {q rows Δ C Γ Φ R p path e a ε}, OpenSound q → BuilderSupport q.formation.atoms Δ →
    CheckFormation.CtxSupport q.formation.atoms Γ → ReturnSupport q.formation.atoms R →
    ExprSupport q e → a.Support (· ∈ q.formation.atoms) → ε.Support (· ∈ q.formation.atoms) →
    g.Support q.formation.atoms → checkExprAt q rows Δ C Γ Φ R p path e a ε g = true →
    OpenSurface.HasTypeQ q.D q.B q.formation.rangeKinds q.opPrim (CheckAdmissible.NoFailCtxOf rows) Δ C Γ Φ R p e a ε

abbrev TypesSoundAt (g : Guide) : Prop :=
  ∀ {q rows Δ C Γ Φ R path es as ε}, OpenSound q → BuilderSupport q.formation.atoms Δ →
    CheckFormation.CtxSupport q.formation.atoms Γ → ReturnSupport q.formation.atoms R →
    ExprsSupport q es → Ty.SupportList (· ∈ q.formation.atoms) as → ε.Support (· ∈ q.formation.atoms) →
    g.Support q.formation.atoms → checkTypesAt q rows Δ C Γ Φ R path es as ε g = true →
    OpenSurface.HasTypesQ q.D q.B q.formation.rangeKinds q.opPrim (CheckAdmissible.NoFailCtxOf rows) Δ C Γ Φ R es as ε

abbrev EachSoundAt (g : Guide) : Prop :=
  ∀ {q rows Δ C Γ Φ R path es a ε}, OpenSound q → BuilderSupport q.formation.atoms Δ →
    CheckFormation.CtxSupport q.formation.atoms Γ → ReturnSupport q.formation.atoms R →
    ExprsSupport q es → a.Support (· ∈ q.formation.atoms) → ε.Support (· ∈ q.formation.atoms) →
    g.Support q.formation.atoms → checkEachAt q rows Δ C Γ Φ R path es a ε g = true →
    OpenSurface.HasEachQ q.D q.B q.formation.rangeKinds q.opPrim (CheckAdmissible.NoFailCtxOf rows) Δ C Γ Φ R es a ε

abbrev FixedSoundAt (g : Guide) : Prop :=
  ∀ {q rows Δ C Γ Φ R path args as ε}, OpenSound q → BuilderSupport q.formation.atoms Δ →
    CheckFormation.CtxSupport q.formation.atoms Γ → ReturnSupport q.formation.atoms R →
    HolesSupport q args → Ty.SupportList (· ∈ q.formation.atoms) as → ε.Support (· ∈ q.formation.atoms) →
    g.Support q.formation.atoms → checkFixedAt q rows Δ C Γ Φ R path args as ε g = true →
    OpenSurface.HasFixedQ q.D q.B q.formation.rangeKinds q.opPrim (CheckAdmissible.NoFailCtxOf rows) Δ C Γ Φ R args as ε

abbrev ArmsSoundAt (g : Guide) : Prop :=
  ∀ {q rows Δ C Γ Φ R p path arms a b ε}, OpenSound q → BuilderSupport q.formation.atoms Δ →
    CheckFormation.CtxSupport q.formation.atoms Γ → ReturnSupport q.formation.atoms R →
    ArmsSupport q arms → a.Support (· ∈ q.formation.atoms) → b.Support (· ∈ q.formation.atoms) →
    ε.Support (· ∈ q.formation.atoms) → g.Support q.formation.atoms →
    checkArmsAt q rows Δ C Γ Φ R p path arms a b ε g = true →
    OpenSurface.HasArmsQ q.D q.B q.formation.rangeKinds q.opPrim (CheckAdmissible.NoFailCtxOf rows) Δ C Γ Φ R p arms a b ε

abbrev ClausesSoundAt (g : Guide) : Prop :=
  ∀ {q rows Δ C Γ Φ R εbody path cs a ε}, OpenSound q → BuilderSupport q.formation.atoms Δ →
    CheckFormation.CtxSupport q.formation.atoms Γ → ReturnSupport q.formation.atoms R →
    ClausesSupport q cs → εbody.Support (· ∈ q.formation.atoms) → a.Support (· ∈ q.formation.atoms) →
    ε.Support (· ∈ q.formation.atoms) → g.Support q.formation.atoms →
    checkClausesAt q rows Δ C Γ Φ R εbody path cs a ε g = true →
    OpenSurface.HasClausesQ q.D q.B q.formation.rangeKinds q.opPrim (CheckAdmissible.NoFailCtxOf rows) Δ C Γ Φ R εbody cs a ε

abbrev BlockSoundAt (g : Guide) : Prop :=
  ∀ {q rows Δ C Γ Φ R p path body a ε}, OpenSound q → BuilderSupport q.formation.atoms Δ →
    CheckFormation.CtxSupport q.formation.atoms Γ → ReturnSupport q.formation.atoms R →
    BlockSupport q body → a.Support (· ∈ q.formation.atoms) → ε.Support (· ∈ q.formation.atoms) →
    g.Support q.formation.atoms → checkBlockAt q rows Δ C Γ Φ R p path body a ε g = true →
    OpenSurface.HasBlockQ q.D q.B q.formation.rangeKinds q.opPrim (CheckAdmissible.NoFailCtxOf rows) Δ C Γ Φ R p body a ε

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

end Benitoite.Release.Refinement.Surface.CheckOpen
