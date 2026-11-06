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

/-- 長さが閉じた整数 n に等しいという篩。 -/
def lengthType (a : Ty) (n : Int) : Ty :=
  .refined (.list a) (.eq (.measure .listLength (.var 0)) (.integer n))

/-- 要素を制約しない、ちょうど n 個の List のパターン。 -/
def exactLengthPattern (n : Nat) : Pat := .list (List.replicate n .wild) none []

private theorem length_eq_eval (xs : List Val) (n : Int) :
    (Pred.eq (.measure .listLength (.var 0)) (.integer n)).evalWith
      (selfModel (fun _ => none) (.list xs)) = some (decide ((xs.length : Int) = n)) := by
  simp [Pred.evalWith, Pred.atomReady, Pred.atomValue, termReady, integerAs, observeAs,
    selfModel, selfObservation, Val.toTerm?, Term.observe, Term.interpret, Observation.sort,
    Observation.measure, MatchFacts.observeSlots_length, Val.toTermSlots_eq_map]

/-- 閉じた長さは任意であり、要素の観測可能性を要求しない。負の長さの型は空である。 -/
theorem length_exhaustive (P : Program) (a : Ty) (n : Int) :
    Exhaustive P (lengthType a n) [exactLengthPattern n.toNat] := by
  intro v hv
  obtain ⟨hc, hp⟩ := hv.refined_inv _ _ rfl
  obtain ⟨xs, rfl, _⟩ := hc.list_inv _ rfl
  have hn : (xs.length : Int) = n := by
    change (Pred.eq (.measure .listLength (.var 0)) (.integer n)).evalWith _ ≠ some false at hp
    rw [length_eq_eval] at hp
    simpa using hp
  have hlen : xs.length = n.toNat := by omega
  refine ⟨exactLengthPattern n.toNat, by simp, ?_⟩
  have hm : (matchList (List.replicate n.toNat .wild) xs).isSome = true :=
    matchList_wild (by simp [isWild]) (by simpa using hlen.symm)
  simp [exactLengthPattern, matchVal, ← hlen, matchList]

/-- 型の篩で制限された初期領域。plain は篩を芯へ忘れた通常の行列判定へ渡す。 -/
inductive InitialDomain : Ty → Type where
  | plain (a : Ty) : InitialDomain a
  | empty (a : Ty) : InitialDomain (.refined a .falsity)
  | month : InitialDomain monthType
  | nonempty (a : Ty) : InitialDomain (nonemptyType a)
  | length (a : Ty) (n : Int) : InitialDomain (lengthType a n)

/-- 初期領域を型の形と有限な述語の構文から選ぶ。 -/
def initialDomain : (a : Ty) → InitialDomain a
  | .refined a .falsity => .empty a
  | .refined (.base .integer) p =>
      if hp : predEq p monthPredicate = true then ((predEq_spec _ _).mp hp).symm ▸ InitialDomain.month else .plain _
  | .refined (.list a) p =>
      if hp : predEq p nonemptyPredicate = true then ((predEq_spec _ _).mp hp).symm ▸ InitialDomain.nonempty a
      else match p with
      | .eq (.measure .listLength (.var 0)) (.integer n) => .length a n
      | _ => .plain _
  | a => .plain a

def InitialDomain.baseType {a : Ty} : InitialDomain a → Ty
  | .plain a | .empty a => a
  | .month => .base .integer
  | .nonempty a | .length a _ => .list a

def InitialDomain.query {a : Ty} : InitialDomain a → Pat
  | .plain _ | .empty _ => .wild
  | .month => monthPattern
  | .nonempty _ => headRestPattern
  | .length _ n => exactLengthPattern n.toNat

private theorem InitialDomain.member {P : Program} {a : Ty} (d : InitialDomain a) {v : Val}
    (hv : Inhabits P a.norm v) :
    Inhabits P d.baseType v ∧ (matchVal d.query v).isSome = true := by
  cases d with
  | plain a => exact ⟨(Inhabits.norm_all_iff _ _).mp hv, rfl⟩
  | empty a =>
      obtain ⟨p, hp, _⟩ := empty_refinement_exhaustive P a v hv
      cases hp
  | month =>
      obtain ⟨p, hp, hm⟩ := month_exhaustive P v hv
      cases List.mem_singleton.mp hp
      exact ⟨(((Inhabits.norm_all_iff _ _).mp hv).refined_inv _ _ rfl).1, hm⟩
  | nonempty a =>
      obtain ⟨p, hp, hm⟩ := nonempty_exhaustive P a v hv
      cases List.mem_singleton.mp hp
      exact ⟨(((Inhabits.norm_all_iff _ _).mp hv).refined_inv _ _ rfl).1, hm⟩
  | length a n =>
      obtain ⟨p, hp, hm⟩ := length_exhaustive P a n v hv
      cases List.mem_singleton.mp hp
      exact ⟨(((Inhabits.norm_all_iff _ _).mp hv).refined_inv _ _ rfl).1, hm⟩

/-- 初期領域の問いを行列へ渡す。空型は値を持たないので、空の腕も網羅的である。 -/
def domainReport (P : Program) (ctors : DataName → List ConName) (view : CoverageView)
    {a : Ty} (d : InitialDomain a) (ps : List Pat) : UsefulnessResult :=
  match d with
  | .empty _ => ⟨none, false⟩
  | _ => usefulReportWithView P ctors view [d.baseType] (ps.map (fun p => [p])) [d.query]

private theorem regionReport_sound (P : Program) (ctors : DataName → List ConName) (view : CoverageView)
    {a : Ty} (d : InitialDomain a) (ps : List Pat) (hc : CtorsComplete P ctors)
    (h : usefulWithView P ctors view [d.baseType] (ps.map (fun p => [p])) [d.query] = none) :
    Exhaustive P a ps := by
  intro v hv
  obtain ⟨hb, hq⟩ := InitialDomain.member d hv
  exact usefulWithView_singleton_none_sound P ctors view _ ps _ hc h v hb hq

/-- 初期領域の選択と行列の成功から、元の篩付きの型の網羅性を得る。 -/
theorem domainReport_sound (P : Program) (ctors : DataName → List ConName) (view : CoverageView)
    {a : Ty} (d : InitialDomain a) (ps : List Pat) (hc : CtorsComplete P ctors)
    (h : (domainReport P ctors view d ps).witness = none) : Exhaustive P a ps := by
  cases d with
  | empty a =>
      intro v hv
      obtain ⟨p, hp, _⟩ := empty_refinement_exhaustive P a v hv
      cases hp
  | plain a => exact regionReport_sound P ctors view (.plain a) ps hc h
  | month => exact regionReport_sound P ctors view .month ps hc h
  | nonempty a => exact regionReport_sound P ctors view (.nonempty a) ps hc h
  | length a n => exact regionReport_sound P ctors view (.length a n) ps hc h

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
    ((i, j), classify (usefulReportWithView P ctors view [a]
      ((precedingPats arms i j).map (fun p => [p])) [alt.pat]))

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
