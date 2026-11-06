import Benitoite.Release.Refinement.CoverageExtension
import Benitoite.Release.Refinement.ClosedDecidable
import Benitoite.Release.Refinement.TermStructuralEq

/-!
# 篩を読む初期領域と、不明を保持する網羅性の結果

空型、整数の閉区間、非空の List、長さの等号から照合の問いを作る。
網羅性と腕の除去は、有限判定が成功した場合だけ行う（設計書 01-12「篩を読む網羅性と値の意味」）。
-/
namespace Benitoite.Release.Refinement
namespace Coverage

private theorem regionReport_extension_sound (P Q : Program)
    (ctors : DataName → List ConName) (view : CoverageView)
    (ext : ConstructorExtension P Q view) (hc : CtorsComplete P ctors)
    {a : Ty} (d : InitialDomain a) (ps : List Pat)
    (h : usefulWithView P ctors view [d.baseType] (ps.map (fun p => [p])) [d.query] = none) :
    Exhaustive Q a ps := by
  intro v hv
  obtain ⟨hb, hq⟩ := InitialDomain.member d hv
  exact usefulWithView_extension_singleton_none_sound P Q ctors view ext hc _ ps _ h v hb hq

private theorem domainReport_extension_sound (P Q : Program)
    (ctors : DataName → List ConName) (view : CoverageView)
    (ext : ConstructorExtension P Q view) (hc : CtorsComplete P ctors)
    {a : Ty} (d : InitialDomain a) (ps : List Pat)
    (h : (domainReport P ctors view d ps).witness = none) : Exhaustive Q a ps := by
  cases d with
  | empty a =>
      intro v hv
      obtain ⟨p, hp, _⟩ := empty_refinement_exhaustive Q a v hv
      cases hp
  | plain a => exact regionReport_extension_sound P Q ctors view ext hc (.plain a) ps h
  | month => exact regionReport_extension_sound P Q ctors view ext hc .month ps h
  | nonempty a => exact regionReport_extension_sound P Q ctors view ext hc (.nonempty a) ps h
  | length a n => exact regionReport_extension_sound P Q ctors view ext hc (.length a n) ps h

/-- 非網羅の証人は診断用の抽象的な形であり、値の実在を主張しない。 -/
inductive Result where
  | exhaustive
  | nonExhaustive (witness : List CoverageWitness)
  | unknown
  deriving Repr

/-- 燃料切れは、反例の有無と独立に unknown として返す。 -/
def classify (r : UsefulnessResult) : Result :=
  if r.fuelExhausted then .unknown else
  match r.witness with
  | none => .exhaustive
  | some ws => .nonExhaustive ws

private theorem classify_exhaustive {r : UsefulnessResult} (h : classify r = .exhaustive) :
    r.witness = none := by
  unfold classify at h
  split at h
  · cases h
  · split at h
    · assumption
    · cases h

/-- 篩付きの型の網羅性の実入口。 -/
def coverage (P : Program) (ctors : DataName → List ConName) (view : CoverageView)
    (a : Ty) (ps : List Pat) : Result :=
  classify (domainReport P ctors view (initialDomain a) ps)

/-- 任意のプログラム・型・パターン列について、成功は網羅性を導く。 -/
theorem coverage_sound (P : Program) (ctors : DataName → List ConName) (view : CoverageView)
    (a : Ty) (ps : List Pat) (hc : CtorsComplete P ctors)
    (h : coverage P ctors view a ps = .exhaustive) : Exhaustive P a ps :=
  domainReport_sound P ctors view (initialDomain a) ps hc (classify_exhaustive h)

/-- 許された型の構成子を加えたどの宣言表でも、同じ篩付きの型の網羅性を保つ。 -/
theorem coverage_extension_sound (P Q : Program) (ctors : DataName → List ConName)
    (view : CoverageView) (ext : ConstructorExtension P Q view) (hc : CtorsComplete P ctors)
    (a : Ty) (ps : List Pat) (h : coverage P ctors view a ps = .exhaustive) : Exhaustive Q a ps :=
  domainReport_extension_sound P Q ctors view ext hc (initialDomain a) ps (classify_exhaustive h)

/-- 開いた経路の含意から同じ値を非空型へ強め、判定の成功で任意のパターン列へ接続する。 -/
theorem typed_nonempty_coverage {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx}
    {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {v : Val} {t : Term}
    (hv : HasTypeVQ P B Ψ Q C Γ Φ v (.list T)) (ht : v.toTerm? = some t)
    (ha : Ty.Annotation P C Γ (.list T)) (hp : nonemptyPredicate.Sorted Γ (some (.list T)))
    (hd : nonemptyPredicate.Declared P C Γ (some (.list T)))
    (he : Entails (Γ.facts ++ Φ) (nonemptyPredicate.open t))
    (ctors : DataName → List ConName) (view : CoverageView) (ps : List Pat)
    (hc : CtorsComplete P ctors)
    (h : coverage P ctors view (nonemptyType T) ps = .exhaustive) :
    HasTypeVQ P B Ψ Q C Γ Φ v (nonemptyType T) ∧ Exhaustive P (nonemptyType T) ps :=
  ⟨(HasTypeVQ.nonempty_from_entails hv ht ha hp hd he).1,
    coverage_sound P ctors view (nonemptyType T) ps hc h⟩

/-- 先行する腕だけで覆われたことが証明済みのときだけ、その選択肢を除く。 -/
def keepAlternative : Result → Bool
  | .exhaustive => false
  | .nonExhaustive _ | .unknown => true

/-- 不明と答えた位置も、選択肢の順を保ったまま残す。 -/
def retainedAlternatives (reports : List ((Nat × Nat) × Result)) : List (Nat × Nat) :=
  (reports.filter (fun r => keepAlternative r.2)).map Prod.fst

theorem unknown_keeps_alternative {reports : List ((Nat × Nat) × Result)} {position : Nat × Nat}
    (h : (position, Result.unknown) ∈ reports) : position ∈ retainedAlternatives reports :=
  List.mem_map.mpr ⟨_, List.mem_filter.mpr ⟨h, rfl⟩, rfl⟩

/-- 各選択肢の前の行について三つの結果を使い、不明な選択肢を保持する。 -/
def alternatives (P : Program) (ctors : DataName → List ConName) (view : CoverageView)
    (a : Ty) (arms : List Arm) : List ((Nat × Nat) × Result) :=
  arms.zipIdx.flatMap fun (arm, i) => arm.alts.zipIdx.map fun (alt, j) =>
    ((i, j), classify (domainAlternativeReport P ctors view (initialDomain a) (precedingPats arms i j) alt.pat))

/-- 網羅性の不明を、腕の除去の根拠にしない入口。 -/
def retained (P : Program) (ctors : DataName → List ConName) (view : CoverageView)
    (a : Ty) (arms : List Arm) : List (Nat × Nat) :=
  retainedAlternatives (alternatives P ctors view a arms)

theorem unknown_keeps_arms {P : Program} {ctors : DataName → List ConName} {view : CoverageView}
    {a : Ty} {arms : List Arm} {position : Nat × Nat}
    (h : (position, Result.unknown) ∈ alternatives P ctors view a arms) :
    position ∈ retained P ctors view a arms := unknown_keeps_alternative h

end Coverage
end Benitoite.Release.Refinement
