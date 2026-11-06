import Benitoite.Release.Refinement.Surface.CheckSupport
import Benitoite.Release.Refinement.Surface.OpenRangeFormationCheck
import Benitoite.Release.Refinement.Surface.CheckOpenFormation
import Benitoite.Release.Refinement.Surface.CheckVariance

/-! # 開いた範囲の検査の入力と、宣言の有限な形成検査 -/
namespace Benitoite.Release.Refinement.Surface.CheckOpen
open Check CheckFormation

abbrev Input := Check.Input

def constructorsClosed (q : Input) : Bool :=
  q.ctorNames.all fun c => match q.D.cons c with
    | none => true
    | some cd => OpenRangeFormationCheck.tys q.formation.atoms 0 cd.args

private theorem ranges_member {nr : Nat} {as : List Ty} (h : rangesScopedTypes nr as) :
    ∀ a ∈ as, a.RangesScoped nr := by
  induction as with
  | nil => intro a ha; cases ha
  | cons a as ih =>
    intro b hb
    rcases List.mem_cons.mp hb with rfl | hb
    · exact h.1
    · exact ih h.2 b hb

/-- 値の型付けを仮定せず、名前の一覧から構成子の範囲閉性を得る。 -/
theorem constructorsClosed_sound {q : Input}
    (hc : CheckVariance.CtorsComplete q.D.core q.ctorNames)
    (hq : q.Sound) (h : constructorsClosed q = true) : PatternRangesClosed q.D.core := by
  intro c cd hcd a ha
  change q.D.cons c = some cd at hcd
  have he := List.all_eq_true.mp h c (hc c cd hcd)
  simp only [hcd] at he
  exact ranges_member (OpenRangeFormationCheck.tys_sound (hq.formation.fields c cd hcd) he) a ha

/-- 内部の規則検査は、実入口で検査した宣言の構文条件を保持する。 -/
structure OpenSound (q : Input) : Prop extends q.Sound where
  constructorsComplete : CheckVariance.CtorsComplete q.D.core q.ctorNames
  constructorsChecked : constructorsClosed q = true

theorem OpenSound.patterns {q} (h : OpenSound q) : PatternRangesClosed q.D.core :=
  constructorsClosed_sound h.constructorsComplete h.toSound h.constructorsChecked

def annotation (q : Input) (C : TypeCtx) (Γ : Ctx) (path : List Nat) (a : Ty) : Bool :=
  CheckOpenFormation.annotation q.formation q.formation.rangeKinds q.D.core C Γ path a

theorem annotation_sound {q C Γ path a} (hq : OpenSound q) (hΓ : CtxSupport q.formation.atoms Γ)
    (ha : a.Support (· ∈ q.formation.atoms)) (h : annotation q C Γ path a = true) :
    Ty.AnnotationR q.D.core q.formation.rangeKinds C Γ a :=
  CheckOpenFormation.annotation_sound hq.formation hΓ ha h

end Benitoite.Release.Refinement.Surface.CheckOpen
