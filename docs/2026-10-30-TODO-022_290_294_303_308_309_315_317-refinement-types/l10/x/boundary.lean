import Lean
import Benitoite.Release.Refinement.CoverageRefinement

namespace Benitoite.Release.Refinement.L10XBoundary
noncomputable section

/-- 外側の値が不明な場合は空 List も残る。 -/
def unknownPredicate : Pred := .lt (.integer 0) (.var 1)

theorem unknown_retained (P : Program) (a : Ty) :
    Inhabits P (.refined (.list a) unknownPredicate) (.list []) :=
  .refined (.list .nil) (by intro h; cases h)

theorem unknown_not_exhaustive (P : Program) (a : Ty) :
    ¬ Exhaustive P (.refined (.list a) unknownPredicate) [headRestPattern] := by
  intro h
  obtain ⟨p,hp,hm⟩ := h (.list []) ((Inhabits.norm_all_iff _ _).mpr (unknown_retained P a))
  have he : p = headRestPattern := List.mem_singleton.mp hp
  subst p
  cases hm

/-- 除外は false が確定した場合だけで、unknown を false に取り替えない。 -/
theorem possible_iff_unknown_or_true (p : Pred) (v : Val) :
    RefinementPossible p v ↔ p.evalWith (selfModel (fun _ => none) v) = none ∨
      p.evalWith (selfModel (fun _ => none) v) = some true := by
  unfold RefinementPossible
  cases h : p.evalWith (selfModel (fun _ => none) v) with
  | none => simp
  | some b => cases b <;> simp

theorem strong_kleene (v : Val) :
    unknownPredicate.evalWith (selfModel (fun _ => none) v) = none ∧
    unknownPredicate.not.evalWith (selfModel (fun _ => none) v) = none ∧
    (unknownPredicate.and .falsity).evalWith (selfModel (fun _ => none) v) = some false ∧
    (Pred.and .falsity unknownPredicate).evalWith (selfModel (fun _ => none) v) = some false ∧
    (unknownPredicate.or .truth).evalWith (selfModel (fun _ => none) v) = some true ∧
    (Pred.or .truth unknownPredicate).evalWith (selfModel (fun _ => none) v) = some true := by
  simp [unknownPredicate,Pred.evalWith,Pred.atomReady,Pred.atomValue,termReady,Term.observe,selfModel]

theorem unknown_with_false_excluded (P : Program) (a : Ty) :
    ¬ Inhabits P (.refined (.list a) (unknownPredicate.and .falsity)) (.list []) := by
  intro h
  have hp := (h.refined_inv _ _ rfl).2
  exact hp (strong_kleene (.list [])).2.2.1

theorem month_13_excluded (P : Program) :
    ¬ Inhabits P monthType (.const (.integer ⟨13,by decide⟩)) := by
  intro h
  exact (h.refined_inv _ _ rfl).2 rfl

theorem checkedAt_opaque_retained (P : Program) (o ix r snapshot target req) :
    Inhabits P (.opaque o ix) (.checkedAt r snapshot target req) := .checkedAtOpaque

/-- 平坦化で消える中間の篩型を束縛しても、正規形の等号による変換で保持する。 -/
def carrier : Ty := .base .integer
def innerPredicate : Pred := .eq (.var 0) (.var 0)
def outerPredicate : Pred := .le (.var 0) (.var 0)
def inner : Ty := .refined carrier innerPredicate
def nested : Ty := .refined inner outerPredicate
def flattened : Ty := .refined carrier (.and innerPredicate outerPredicate)
def image : Nat → Val := fun _ => .const .unit

theorem source_pattern (P : Program) : PatTy P .var nested [inner] := .P_Refined .P_Var

/-- P_Var と P_Refined だけからなる、実際の PatTy の変数の導出。 -/
inductive WithoutConversion (P : Program) : {a : Ty} → {δ : List Ty} → PatTy P .var a δ → Prop where
  | variable {a} : WithoutConversion P (PatTy.P_Var (a := a))
  | refined {a φ δ} {h : PatTy P .var a δ} : WithoutConversion P h →
      WithoutConversion P (PatTy.P_Refined (φ := φ) h)

/-- 正規形の変換を含まない元の規則だけでは、中間の束縛型を得られない。 -/
theorem flattened_requires_conversion (P : Program) (h : PatTy P .var flattened [inner]) :
    ¬ WithoutConversion P h := by
  intro hc
  cases hc with
  | refined hc => cases hc

theorem flattened_pattern (P : Program) : PatTy P .var flattened [inner] := by
  simpa only [List.map_cons,List.map_nil,show inner.norm = inner from rfl] using
    (PatTy.P_Convert (a := nested) (b := flattened) rfl (source_pattern P))

theorem substituted_pattern (P : Program) :
    PatTy P .var (substTyValues image nested) ([inner].map (substTyValues image)) :=
  (source_pattern P).subst_values image

theorem meaning_not_possible_only (P : Program) :
    Inhabits P (.refined (.fn [] [] (.base .unit) Eff.empty) unknownPredicate)
        (.fnRef "f" [] []) ∧
    ¬ ValueMeaning P (fun _ => none)
      (.refined (.fn [] [] (.base .unit) Eff.empty) (unknownPredicate.and unknownPredicate.not))
      (.fnRef "f" [] []) := by
  constructor
  · exact .refined .fn (by intro h; cases h)
  · intro h
    have hp := (ValueMeaning.refined_iff.mp h).2
    cases hu : unknownPredicate.interpret (selfModel (fun _ => none) (.fnRef "f" [] [])) <;>
      simp [Pred.interpret,hu] at hp

/-- scoped_forget に対する G09 の完全署名の特殊化。新しい前提は不要である。 -/
theorem scoped_forget_sub_contract {P : Program} {Γ : Ctx} {Φ : List Pred}
    {o k ix v} {η : ObservationEnvModel} :
    P.VarianceValid → Ty.LeQ P Γ Φ (.scoped o k ix) (.opaque o ix) →
    (∀ p ∈ Γ.facts ++ Φ, p.interpret η = true) →
    ValueMeaning P η (.scoped o k ix) v → ValueMeaning P η (.opaque o ix) v := by
  intro _ _ _ h
  exact h.scoped_forget

/-- Ty.LeQ.scoped が使う Covers と同じ向きで意味を移す。 -/
theorem scoped_sub_contract {P : Program} {Γ : Ctx} {Φ : List Pred}
    {o k inner outer v} {η : ObservationEnvModel}
    (hc : RangeIx.Covers outer inner) :
    P.VarianceValid → Ty.LeQ P Γ Φ (.scoped o k inner) (.scoped o k outer) →
    (∀ p ∈ Γ.facts ++ Φ, p.interpret η = true) →
    ValueMeaning P η (.scoped o k inner) v → ValueMeaning P η (.scoped o k outer) v := by
  intro _ _ _ h
  exact h.scoped_covers hc

/-- 旧反例の unit は scoped の意味を持たない。 -/
theorem scoped_rejects_unit (P η o k ix) :
    ¬ ValueMeaning P η (.scoped o k ix) (.const .unit) := by
  intro h
  cases h.scoped_inv

/-- 従来の Inhabits の上側近似を狭めてはいない。 -/
theorem scoped_inhabits_unit (P o k ix) : Inhabits P (.scoped o k ix) (.const .unit) := .scoped

/-- fixed の成功値は checked と checkedRequest、任意の添字には checkedAt を保持する。 -/
theorem scoped_success_shapes (P η o k r target req ix snapshot) :
    ValueMeaning P η (.scoped o k (.fixed r)) (.checked target) ∧
    ValueMeaning P η (.scoped o k (.fixed r)) (.checkedRequest target req) ∧
    ValueMeaning P η (.scoped o k ix) (.checkedAt r snapshot target req) :=
  ⟨.of_scoped .checked, .of_scoped .checkedRequest, .of_scoped .checkedAt⟩

/-- fixed 向けの成功値を変数添字の意味へは混入させない。 -/
theorem variable_scoped_rejects_checked (P η o k i target) :
    ¬ ValueMeaning P η (.scoped o k (.rvar i)) (.checked target) := by
  intro h
  cases h.scoped_inv

/-- 値依存の等号だけなら空 List は残り、頭と残りの腕だけでは網羅でない。 -/
def lenEq : Pred := .eq (.measure .listLength (.var 0)) (.var 1)
theorem length_equality_not_exhaustive (P a) :
    ¬ Exhaustive P (.refined (.list a) lenEq) [headRestPattern] := by
  intro h
  have hi : Inhabits P (.refined (.list a) lenEq) (.list []) :=
    .refined (.list .nil) (by intro h; simp [lenEq,Pred.evalWith,Pred.atomReady,termReady,Term.observe,selfModel] at h)
  obtain ⟨p,hp,hm⟩ := h (.list []) ((Inhabits.norm_all_iff _ _).mpr hi)
  have he : p = headRestPattern := List.mem_singleton.mp hp
  subst p; cases hm


/-- rv-x-t4 の開いた型付けから非空型と網羅性を得る実例。 -/
theorem open_nonempty_instance (P : Program) (B : Builtins) (Ψ : StoreTy) :
    let T : Ty := .base .unit
    let Γ : Ctx := [some (.list T)]
    let Φ : List Pred := [nonemptyPredicate.open (.var 0)]
    HasTypeVQ P B Ψ Qempty [] Γ Φ (.var 0) (nonemptyType T) ∧
      Exhaustive P (nonemptyType T) [headRestPattern] := by
  intro T Γ Φ
  have self : (Term.var 0).HasSort [some (.list T), some (.list T)] .list :=
    ⟨⟨.list T,rfl,by intro b t e he; cases he⟩,⟨.list T,rfl,rfl⟩⟩
  have hv : HasTypeVQ P B Ψ Qempty [] Γ Φ (.var 0) (.list T) :=
    .V_Var rfl (by intro b t e he; cases he)
  have ha : Ty.Annotation P [] Γ (.list T) := by
    refine ⟨?_,?_,?_⟩ <;> simp [T,Ty.WF,Ty.Sorted,Ty.Declared]
  have sint : ∀ k : Int, (Term.integer k).HasSort (some (.list T) :: Γ) .integer := fun _ => ⟨trivial,rfl⟩
  have hp : nonemptyPredicate.Sorted Γ (some (.list T)) :=
    ⟨sint 0,⟨self.1,⟨self.2,rfl⟩⟩⟩
  have hd : nonemptyPredicate.Declared P [] Γ (some (.list T)) :=
    ⟨trivial,⟨_,rfl,by intro b t e he; cases he⟩⟩
  exact hv.nonempty_from_entails rfl ha hp hd (.hyp (by simp [Φ]))


end
end Benitoite.Release.Refinement.L10XBoundary



open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if name.toString.startsWith "Benitoite.Release.Refinement.L10XBoundary." then some name else none).mergeSort
      (fun a b => a.toString < b.toString)
  logInfo m!"BOUNDARY_DECLARATIONS {names.length}"
  for name in names do elabCommand (← `(#print axioms $(mkIdent name)))
