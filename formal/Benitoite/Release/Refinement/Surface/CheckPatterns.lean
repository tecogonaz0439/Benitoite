import Benitoite.Release.Refinement.Surface.CheckPatternFacts
import Benitoite.Release.Refinement.Surface.CheckArguments
import Benitoite.Release.Refinement.CoverageInitial

/-! パターンの束縛型の推論と、将来の宣言を含む網羅性の検査。 -/
namespace Benitoite.Release.Refinement.Surface.CheckPatterns
open CheckCompare

mutual
  def patternValid : Pattern → Bool
    | .range (.integer lo) (.integer hi) => decide (lo.toInt ≤ hi.toInt)
    | .range (.character lo) (.character hi) => decide (lo.toNat ≤ hi.toNat)
    | .con _ _ ps | .record _ _ _ ps => patternsValid ps
    | .list before rest after => patternsValid before && (patternsValid after &&
        (rest.isSome || after.isEmpty))
    | _ => true
  def patternsValid : List Pattern → Bool
    | [] => true
    | p :: ps => patternValid p && patternsValid ps
end

mutual
  theorem patternValid_spec : (p : Pattern) → (patternValid p = true ↔ p.Valid)
    | .wild => by simp [patternValid, Pattern.Valid]
    | .var => by simp [patternValid, Pattern.Valid]
    | .integer _ => by simp [patternValid, Pattern.Valid]
    | .negInt _ => by simp [patternValid, Pattern.Valid]
    | .string _ => by simp [patternValid, Pattern.Valid]
    | .character _ => by simp [patternValid, Pattern.Valid]
    | .boolean _ => by simp [patternValid, Pattern.Valid]
    | .unit => by simp [patternValid, Pattern.Valid]
    | .range lo hi => by cases lo <;> cases hi <;> simp [patternValid, Pattern.Valid]
    | .con _ _ ps => by simp [patternValid, Pattern.Valid, patternsValid_spec ps]
    | .record _ _ _ ps => by simp [patternValid, Pattern.Valid, patternsValid_spec ps]
    | .list before rest after => by
        cases rest <;> simp [patternValid, Pattern.Valid, patternsValid_spec before, patternsValid_spec after]
  theorem patternsValid_spec : (ps : List Pattern) → (patternsValid ps = true ↔ Pattern.ValidList ps)
    | [] => by simp [patternsValid, Pattern.ValidList]
    | p :: ps => by simp [patternsValid, Pattern.ValidList, patternValid_spec p, patternsValid_spec ps]
end

instance patternValidDecidable (p : Pattern) : Decidable p.Valid :=
  decidable_of_iff (patternValid p = true) (patternValid_spec p)

instance patternNontrivialDecidable (p : Pattern) : Decidable p.Nontrivial := by
  cases p <;> unfold Pattern.Nontrivial <;> infer_instance

def alternativesValid (alts : List Alternative) : Bool := alts.all fun alt => patternValid alt.pat

theorem alternativesValid_spec (alts : List Alternative) :
    alternativesValid alts = true ↔ Alternative.Valid alts := by
  simp only [alternativesValid, Alternative.Valid, List.all_eq_true, patternValid_spec]

instance alternativesValidDecidable (alts : List Alternative) : Decidable (Alternative.Valid alts) :=
  decidable_of_iff (alternativesValid alts = true) (alternativesValid_spec alts)

private def constPatBase : Benitoite.Release.Const → Option BaseTy
  | .integer _ => some .integer
  | .string _ => some .string
  | .character _ => some .character
  | .boolean _ => some .boolean
  | .unit => some .unit
  | _ => none

private theorem constPatBase_sound {P : Refinement.Program} {c : Benitoite.Release.Const} {b : BaseTy}
    (h : constPatBase c = some b) : PatTy P (.const c) (.base b) [] := by
  cases c <;> simp only [constPatBase, Option.some.injEq, reduceCtorEq] at h
  all_goals subst b; exact .P_Const rfl

private def rangePatBase : Benitoite.Release.Const → Benitoite.Release.Const → Option BaseTy
  | .integer _, .integer _ => some .integer
  | .character _, .character _ => some .character
  | _, _ => none

private theorem rangePatBase_sound {P : Refinement.Program}
    {lo hi : Benitoite.Release.Const} {b : BaseTy} (h : rangePatBase lo hi = some b) :
    PatTy P (.range lo hi) (.base b) [] := by
  cases lo <;> cases hi <;> simp only [rangePatBase, Option.some.injEq, reduceCtorEq] at h
  all_goals subst b; constructor

private theorem pat_of_core {P : Refinement.Program} {p : Pat} {a : Ty} {δ : List Ty}
    (h : PatTy P p a.core δ) : PatTy P p a δ := by
  cases a with
  | refined a φ => exact .P_Refined (pat_of_core (a := a) h)
  | _ => exact h

private theorem supported_append {s : List Atom} {as bs : List Ty}
    (ha : Ty.SupportList (· ∈ s) as) (hb : Ty.SupportList (· ∈ s) bs) :
    Ty.SupportList (· ∈ s) (as ++ bs) := by
  induction as with
  | nil => exact hb
  | cons a as ih => exact ⟨ha.1, ih ha.2⟩

private theorem supported_replicate {s : List Atom} {a : Ty} (h : a.Support (· ∈ s)) (n : Nat) :
    Ty.SupportList (· ∈ s) (List.replicate n a) := by
  induction n with
  | zero => trivial
  | succ n ih => exact ⟨h, ih⟩

private theorem supported_subst {q : CheckFormation.Input} {as ts : List Ty}
    (ha : Ty.SupportList (· ∈ q.atoms) as) (ht : Ty.SupportList (· ∈ q.atoms) ts) :
    Ty.SupportList (· ∈ q.atoms) (as.map (CheckFormation.substTy q ts [])) := by
  apply Ty.SupportList.iff.mpr
  intro a hm
  obtain ⟨b, hb, rfl⟩ := List.mem_map.mp hm
  exact CheckFormation.substTy_support (Ty.SupportList.iff.mp ha b hb) ht (by simp)

private theorem supported_rest {s : List Atom} {a : Ty} (ha : a.Support (· ∈ s)) (r : Option ListRest) :
    Ty.SupportList (· ∈ s) (restTys r a) := by
  cases r with
  | none => trivial
  | some r => cases r <;> simp only [restTys, Ty.SupportList, Ty.Support] <;> first | trivial | exact ⟨ha, trivial⟩

mutual
  private def patRaw (q : CheckFormation.Input) (P : Refinement.Program) : Pat → Ty → Option (List Ty)
    | .wild, _ => some []
    | .var, a => some [a]
    | .const c, a => match a.core, constPatBase c with
      | .base b, some b' => if b = b' then some [] else none
      | _, _ => none
    | .range lo hi, a => match a.core, rangePatBase lo hi with
      | .base b, some b' => if b = b' then some [] else none
      | _, _ => none
    | .list before rest after, a => match a.core with
      | .list t =>
          if rest.isSome || after.isEmpty then do
            let δb ← patsRaw q P before (List.replicate before.length t)
            let δa ← patsRaw q P after (List.replicate after.length t)
            pure (δb ++ restTys rest t ++ δa)
          else none
      | _ => none
    | .con c ps, a => match a.core with
      | .data d ts => do
          let cd ← P.cons c
          if cd.data = d ∧ ts.length = cd.ntys then
            if CheckFormation.wfTys q 0 cd.ntys 0 cd.args then
              patsRaw q P ps (cd.args.map (CheckFormation.substTy q ts []))
            else none
          else none
      | _ => none
  private def patsRaw (q : CheckFormation.Input) (P : Refinement.Program) :
      List Pat → List Ty → Option (List Ty)
    | [], [] => some []
    | p :: ps, a :: as => do
        let δ ← patRaw q P p a
        let δs ← patsRaw q P ps as
        pure (δ ++ δs)
    | _, _ => none
end

mutual
  private theorem patRaw_checked {q : CheckFormation.Input} {P : Refinement.Program}
      (hq : q.Sound P) {p : Pat} {a : Ty} {δ : List Ty} (ha : a.Support (· ∈ q.atoms))
      (h : patRaw q P p a = some δ) : PatTy P p a δ ∧ Ty.SupportList (· ∈ q.atoms) δ := by
    have hcore : a.core.Support (· ∈ q.atoms) := (Ty.support_core_iff _ _).mpr ha
    cases p with
    | wild => cases h; exact ⟨.P_Wild, trivial⟩
    | var => cases h; exact ⟨.P_Var, ha, trivial⟩
    | const c =>
        cases he : a.core <;> simp only [patRaw, he, reduceCtorEq] at h
        rename_i b
        cases hb : constPatBase c with
        | none => simp [hb] at h
        | some b' =>
            simp only [hb] at h
            split at h
            · next hbb =>
              subst b'
              cases h
              exact ⟨pat_of_core (he ▸ constPatBase_sound hb), trivial⟩
            · cases h
    | range lo hi =>
        cases he : a.core <;> simp only [patRaw, he, reduceCtorEq] at h
        rename_i b
        cases hb : rangePatBase lo hi with
        | none => simp [hb] at h
        | some b' =>
            simp only [hb] at h
            split at h
            · next hbb =>
              subst b'
              cases h
              exact ⟨pat_of_core (he ▸ rangePatBase_sound hb), trivial⟩
            · cases h
    | list before rest after =>
        cases he : a.core <;> simp only [patRaw, he, reduceCtorEq] at h
        rename_i t
        split at h
        · next hr =>
          obtain ⟨δb, hb, h⟩ := Option.bind_eq_some_iff.mp h
          obtain ⟨δa, he', h⟩ := Option.bind_eq_some_iff.mp h
          simp only [pure, Option.some.injEq] at h
          subst δ
          have ht : t.Support (· ∈ q.atoms) := by simpa only [he, Ty.Support] using hcore
          obtain ⟨hpb, hsb⟩ := patsRaw_checked hq (supported_replicate ht _) hb
          obtain ⟨hpa, hsa⟩ := patsRaw_checked hq (supported_replicate ht _) he'
          refine ⟨pat_of_core (he ▸ PatTy.P_List hpb hpa ?_),
            supported_append (supported_append hsb (supported_rest ht rest)) hsa⟩
          intro hn
          simpa [hn] using hr
        · cases h
    | con c ps =>
        cases he : a.core <;> simp only [patRaw, he, reduceCtorEq] at h
        rename_i d ts
        obtain ⟨cd, hc, h⟩ := Option.bind_eq_some_iff.mp h
        split at h
        · next hd =>
          split at h
          · next hw =>
            have hts : Ty.SupportList (· ∈ q.atoms) ts := by simpa only [he, Ty.Support] using hcore
            have hf := hq.fields c cd hc
            obtain ⟨ht, hs⟩ := patsRaw_checked hq (supported_subst hf hts) h
            have hsub : cd.args.map (CheckFormation.substTy q ts []) = cd.args.map (Ty.subst ts []) :=
              List.map_congr_left fun t hm => CheckFormation.substTy_eq (Ty.SupportList.iff.mp hf t hm) hts (by simp)
            rw [hsub] at ht
            have hfields : ∀ t ∈ cd.args, t.WF 0 cd.ntys 0 :=
              Ty.wfList_iff.mp (CheckFormation.wfTys_sound hf hw)
            exact ⟨pat_of_core (he ▸ (hd.1 ▸ PatTy.P_Con hc hd.2 hfields ht)), hs⟩
          · cases h
        · cases h
  termination_by sizeOf p
  decreasing_by all_goals (subst_vars; simp_wf <;> omega)

  private theorem patsRaw_checked {q : CheckFormation.Input} {P : Refinement.Program}
      (hq : q.Sound P) {ps : List Pat} {as δ : List Ty} (ha : Ty.SupportList (· ∈ q.atoms) as)
      (h : patsRaw q P ps as = some δ) : PatTys P ps as δ ∧ Ty.SupportList (· ∈ q.atoms) δ := by
    cases ps with
    | nil => cases as <;> first | cases h; exact ⟨.nil, trivial⟩ | cases h
    | cons p ps =>
      cases as with
      | nil => cases h
      | cons a as =>
        simp only [patsRaw] at h
        obtain ⟨δp, hp, h⟩ := Option.bind_eq_some_iff.mp h
        obtain ⟨δs, hs, h⟩ := Option.bind_eq_some_iff.mp h
        simp only [pure, Option.some.injEq] at h
        subst δ
        obtain ⟨ht, hst⟩ := patRaw_checked hq ha.1 hp
        obtain ⟨hts, hsts⟩ := patsRaw_checked hq ha.2 hs
        exact ⟨.cons ht hts, supported_append hst hsts⟩
  termination_by sizeOf ps
  decreasing_by all_goals (subst_vars; simp_wf <;> omega)
end

/-- 篩を保持した束縛型を正規化して返す。 -/
def patTy (q : CheckFormation.Input) (P : Refinement.Program) (p : Pat) (a : Ty) : Option (List Ty) :=
  (patRaw q P p a).map (List.map (Ty.normWith q.atoms))

private theorem patTy_checked {q P p a δ} (hq : q.Sound P) (ha : a.Support (· ∈ q.atoms))
    (h : patTy q P p a = some δ) : PatTy P p a δ ∧ Ty.SupportList (· ∈ q.atoms) δ := by
  cases hr : patRaw q P p a with
  | none => simp [patTy, hr] at h
  | some ds =>
      simp only [patTy, hr, Option.map_some, Option.some.injEq] at h
      subst δ
      obtain ⟨ht, hs⟩ := patRaw_checked hq ha hr
      have he : ds.map (Ty.normWith q.atoms) = ds.map Ty.norm := List.map_congr_left fun a hm =>
        Ty.normWith_eq_norm q.atoms a (Ty.SupportList.iff.mp hs a hm)
      refine ⟨he ▸ PatTy.P_Convert rfl ht, ?_⟩
      apply Ty.SupportList.iff.mpr
      intro t hm
      obtain ⟨a, haMem, rfl⟩ := List.mem_map.mp hm
      exact Ty.normWith_support q.atoms a (Ty.SupportList.iff.mp hs a haMem)

theorem patTy_sound {q P p a δ} (hq : q.Sound P) (ha : a.Support (· ∈ q.atoms))
    (h : patTy q P p a = some δ) : PatTy P p a δ := (patTy_checked hq ha h).1

theorem patTy_support {q P p a δ} (hq : q.Sound P) (ha : a.Support (· ∈ q.atoms))
    (h : patTy q P p a = some δ) : Ty.SupportList (· ∈ q.atoms) δ := (patTy_checked hq ha h).2

/-- ソースのパターンを規範の核のパターンへ写してから検査する。 -/
def surfacePatTy (q : CheckFormation.Input) (D : Declarations) (p : Pattern) (a : Ty) : Option (List Ty) :=
  patTy q D.core p.toCore a

theorem surfacePatTy_sound {q D p a δ} (hq : q.Sound D.core) (ha : a.Support (· ∈ q.atoms))
    (h : surfacePatTy q D p a = some δ) : PatTy D.core p.toCore a δ := patTy_sound hq ha h

theorem surfacePatTy_support {q D p a δ} (hq : q.Sound D.core) (ha : a.Support (· ∈ q.atoms))
    (h : surfacePatTy q D p a = some δ) : Ty.SupportList (· ∈ q.atoms) δ := patTy_support hq ha h

/-- 複数のパターンを書いた順に検査し、束縛型を連結する。 -/
def patTys (q : CheckFormation.Input) (P : Refinement.Program) : List Pat → List Ty → Option (List Ty)
  | [], [] => some []
  | p :: ps, a :: as => do
      let δ ← patTy q P p a
      let δs ← patTys q P ps as
      pure (δ ++ δs)
  | _, _ => none

private theorem patTys_checked {q P ps as δ} (hq : q.Sound P) (ha : Ty.SupportList (· ∈ q.atoms) as)
    (h : patTys q P ps as = some δ) : PatTys P ps as δ ∧ Ty.SupportList (· ∈ q.atoms) δ := by
  induction ps generalizing as δ with
  | nil => cases as <;> first | cases h; exact ⟨.nil, trivial⟩ | cases h
  | cons p ps ih => cases as with
    | nil => cases h
    | cons a as =>
      simp only [patTys] at h
      obtain ⟨δp, hp, h⟩ := Option.bind_eq_some_iff.mp h
      obtain ⟨δs, hs, h⟩ := Option.bind_eq_some_iff.mp h
      simp only [pure, Option.some.injEq] at h
      subst δ
      obtain ⟨ht, hst⟩ := patTy_checked hq ha.1 hp
      obtain ⟨hts, hsts⟩ := ih ha.2 hs
      exact ⟨.cons ht hts, supported_append hst hsts⟩

theorem patTys_sound {q P ps as δ} (hq : q.Sound P) (ha : Ty.SupportList (· ∈ q.atoms) as)
    (h : patTys q P ps as = some δ) : PatTys P ps as δ := (patTys_checked hq ha h).1

theorem patTys_support {q P ps as δ} (hq : q.Sound P) (ha : Ty.SupportList (· ∈ q.atoms) as)
    (h : patTys q P ps as = some δ) : Ty.SupportList (· ∈ q.atoms) δ := (patTys_checked hq ha h).2

private def checkAlt (q : CheckFormation.Input) (P : Refinement.Program) (a : Ty) (δ : List Ty) (alt : Alt) : Bool :=
  match patTy q P alt.pat a with
  | none => false
  | some γ => decide (alt.slots.Perm (List.range γ.length)) &&
      match selectSlots γ alt.slots with
      | none => false
      | some ds => CheckArguments.tysEq q.atoms ds δ

def checkAlts (q : CheckFormation.Input) (P : Refinement.Program) (alts : List Alt) (a : Ty) (δ : List Ty) : Bool :=
  match alts with
  | [] => false
  | first :: _ => decide (δ.length = Arm.bindersOf alts) &&
      (decide (first.slots = List.range first.pat.binders) && alts.all (checkAlt q P a δ))

private theorem supported_select {s : List Atom} {as bs : List Ty} {slots : List Nat}
    (h : Ty.SupportList (· ∈ s) as) (hs : selectSlots as slots = some bs) : Ty.SupportList (· ∈ s) bs :=
  Ty.SupportList.iff.mpr fun a ha => Ty.SupportList.iff.mp h a (selectSlots_mem hs a ha)

theorem checkAlts_sound {q P alts a δ} (hq : q.Sound P)
    (ha : a.Support (· ∈ q.atoms)) (hd : Ty.SupportList (· ∈ q.atoms) δ)
    (h : checkAlts q P alts a δ = true) : AltsTy P alts a δ := by
  cases alts with
  | nil => cases h
  | cons first rest =>
    simp only [checkAlts, Bool.and_eq_true, decide_eq_true_eq, List.all_eq_true] at h
    refine ⟨by simp, h.1, ?_, ?_⟩
    · intro alt he
      cases Option.some.inj he
      exact h.2.1
    · intro alt hm
      have hc := h.2.2 alt hm
      unfold checkAlt at hc
      cases hg : patTy q P alt.pat a with
      | none => simp [hg] at hc
      | some γ =>
        simp only [hg, Bool.and_eq_true, decide_eq_true_eq] at hc
        cases hs : selectSlots γ alt.slots with
        | none => simp [hs] at hc
        | some ds =>
          have he := CheckArguments.tysEq_sound (supported_select (patTy_support hq ha hg) hs) hd
            (by simpa only [hs] using hc.2)
          exact ⟨γ, patTy_sound hq ha hg, hc.1, he ▸ hs⟩

/-- 最初の選択肢から束縛型を求め、全ての並べ替えを照合する。 -/
def altsTy (q : CheckFormation.Input) (P : Refinement.Program) (alts : List Alt) (a : Ty) : Option (List Ty) := do
  let first ← alts.head?
  let δ ← patTy q P first.pat a
  if checkAlts q P alts a δ then some δ else none

private theorem altsTy_checked {q P alts a δ} (hq : q.Sound P) (ha : a.Support (· ∈ q.atoms))
    (h : altsTy q P alts a = some δ) : AltsTy P alts a δ ∧ Ty.SupportList (· ∈ q.atoms) δ := by
  unfold altsTy at h
  obtain ⟨first, hf, h⟩ := Option.bind_eq_some_iff.mp h
  obtain ⟨γ, hg, h⟩ := Option.bind_eq_some_iff.mp h
  split at h
  · next hc =>
    simp only [Option.some.injEq] at h
    subst δ
    have hs := patTy_support hq ha hg
    exact ⟨checkAlts_sound hq ha hs hc, hs⟩
  · cases h

theorem altsTy_sound {q P alts a δ} (hq : q.Sound P) (ha : a.Support (· ∈ q.atoms))
    (h : altsTy q P alts a = some δ) : AltsTy P alts a δ := (altsTy_checked hq ha h).1

theorem altsTy_support {q P alts a δ} (hq : q.Sound P) (ha : a.Support (· ∈ q.atoms))
    (h : altsTy q P alts a = some δ) : Ty.SupportList (· ∈ q.atoms) δ := (altsTy_checked hq ha h).2

/-- 初期領域を含めて、将来の構成子も考慮する有限の判定を使う。 -/
def exhaustiveWithView (D : Declarations) (ctors : DataName → List ConName) (view : CoverageView)
    (a : Ty) (ps : List Pat) : Bool :=
  match Coverage.coverage D.core ctors view a ps with
  | .exhaustive => true
  | .nonExhaustive _ | .unknown => false

private theorem exhaustiveWithView_checked {D ctors view a ps}
    (h : exhaustiveWithView D ctors view a ps = true) :
    Coverage.coverage D.core ctors view a ps = .exhaustive := by
  unfold exhaustiveWithView at h
  split at h
  · assumption
  · cases h
  · cases h

theorem exhaustiveWithView_view {D ctors view a ps} (hc : CtorsComplete D.core ctors)
    (h : exhaustiveWithView D ctors view a ps = true) : ViewExhaustive D view a ps := by
  intro P' hP
  exact Coverage.coverage_extension_sound D.core P' ctors view ⟨hP.keep, hP.future⟩ hc a ps
    (exhaustiveWithView_checked h)

theorem exhaustiveWithView_sound {D ctors view a ps} (hc : CtorsComplete D.core ctors)
    (h : exhaustiveWithView D ctors view a ps = true) : Exhaustive D.core a ps :=
  Coverage.coverage_sound D.core ctors view a ps hc (exhaustiveWithView_checked h)

end Benitoite.Release.Refinement.Surface.CheckPatterns
