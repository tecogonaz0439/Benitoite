import Benitoite.Surface.CheckPredicates

/-! パターンの束縛型の計算と、表層の各規則に対応する網羅性の包み。 -/
namespace Benitoite.Surface.CheckTools
open Benitoite.Release

/-- コアに許された定数の型。Float・Byte・Decimal・Opaque はパターンに許さない。 -/
def constPatBase : Release.Const → Option BaseTy
  | .integer _ => some .integer
  | .string _ => some .string
  | .character _ => some .character
  | .boolean _ => some .boolean
  | .unit => some .unit
  | _ => none

mutual
  def patTy (P : Release.Program) : Release.Pat → Ty → Option (List Ty)
    | .wild, _ => some []
    | .var, a => some [a]
    | .const c, .base b =>
        match constPatBase c with
        | some b' => if b == b' then some [] else none
        | none => none
    | .range (.integer _) (.integer _), .base .integer => some []
    | .range (.character _) (.character _), .base .character => some []
    | .list before rest after, .list a => do
        if rest.isSome || after.isEmpty then
          let δb ← patTys P before (List.replicate before.length a)
          let δa ← patTys P after (List.replicate after.length a)
          pure (δb ++ restTys rest a ++ δa)
        else none
    | .con c ps, .data d ts => do
        let cd ← P.cons c
        if cd.data == d && decide (ts.length = cd.ntys) then
          patTys P ps (substTysAt 0 ts [] cd.args)
        else none
    | _, _ => none
  def patTys (P : Release.Program) : List Release.Pat → List Ty → Option (List Ty)
    | [], [] => some []
    | p :: ps, a :: as => do
        let δ ← patTy P p a
        let δs ← patTys P ps as
        pure (δ ++ δs)
    | _, _ => none
end

private theorem pat_sound (P : Release.Program) :
    (∀ p a δ, patTy P p a = some δ → PatTy P p a δ) ∧
    (∀ ps as δ, patTys P ps as = some δ → PatTys P ps as δ) := by
  apply patTy.mutual_induct
    (motive_1 := fun p a => ∀ δ, patTy P p a = some δ → PatTy P p a δ)
    (motive_2 := fun ps as => ∀ δ, patTys P ps as = some δ → PatTys P ps as δ)
  · intro a δ h; simp only [patTy, Option.some.injEq] at h; subst δ; exact .P_Wild
  · intro a δ h; simp only [patTy, Option.some.injEq] at h; subst δ; exact .P_Var
  · intro c b b' hc hb δ h
    have eb := eq_of_beq hb
    subst b'
    cases c <;> simp_all [constPatBase, patTy]
      <;> obtain ⟨rfl, rfl⟩ := h
      <;> exact .P_Const (by intros; simp) (by intros; simp)
        (by intros; simp) (by intros; simp)
  · intro c b b' hc hb δ h; simp [patTy, hc, hb] at h
  · intro c b hc δ h; simp [patTy, hc] at h
  · intro lo hi δ h; simp only [patTy, Option.some.injEq] at h; subst δ; exact .P_RangeInt
  · intro lo hi δ h; simp only [patTy, Option.some.injEq] at h; subst δ; exact .P_RangeChar
  · intro before rest after a hr ihb iha δ h
    simp only [patTy, hr, ↓reduceIte] at h
    obtain ⟨δb, hb, h⟩ := Option.bind_eq_some_iff.mp h
    obtain ⟨δa, ha, h⟩ := Option.bind_eq_some_iff.mp h
    simp only [pure, Option.some.injEq] at h
    subst δ
    apply PatTy.P_List (ihb _ hb) (iha _ ha)
    intro hn
    simpa [hn] using hr
  · intro before rest after a hr δ h; simp [patTy, hr] at h
  · intro c ps d ts ih δ h
    simp only [patTy] at h
    obtain ⟨cd, hc, h⟩ := Option.bind_eq_some_iff.mp h
    split at h
    · rename_i hh
      have ⟨hd, hn⟩ := Bool.and_eq_true_iff.mp hh
      have ed := eq_of_beq hd
      subst d
      apply PatTy.P_Con hc (of_decide_eq_true hn)
      change PatTys P ps (cd.args.map (Ty.substAt 0 ts [])) δ
      rw [← substTysAt_eq]
      apply ih cd δ; assumption
    · contradiction
  · intro p a hw hv hc hi hh hl hk δ h
    simp only [patTy] at h
    contradiction
  · intro δ h; simp only [patTys, Option.some.injEq] at h; subst δ; exact .nil
  · intro p ps a as ihp ihs δ h
    simp only [patTys] at h
    obtain ⟨δp, hp, h⟩ := Option.bind_eq_some_iff.mp h
    obtain ⟨δs, hs, h⟩ := Option.bind_eq_some_iff.mp h
    simp only [pure, Option.some.injEq] at h
    subst δ
    exact .cons (ihp _ hp) (ihs _ hs)
  · intro ps as hn hc δ h
    simp only [patTys] at h
    contradiction

theorem patTy_sound {P p a δ} (h : patTy P p a = some δ) : PatTy P p a δ :=
  (pat_sound P).1 p a δ h

theorem patTys_sound {P ps as δ} (h : patTys P ps as = some δ) : PatTys P ps as δ :=
  (pat_sound P).2 ps as δ h

/-- レコードは toCore によって宣言順に並べ、省略したフィールドを wild にする。 -/
def surfacePatTy (D : Declarations) (p : Pattern) (a : Ty) : Option (List Ty) :=
  patTy D.patternProgram p.toCore a

theorem surfacePatTy_sound {D p a δ} (h : surfacePatTy D p a = some δ) :
    PatTy D.patternProgram p.toCore a δ := patTy_sound h

def ConAtomsIn (atoms : List Atom) (P : Release.Program) : Prop :=
  ∀ c cd, P.cons c = some cd → Tys.AtomsIn atoms cd.args

mutual
  theorem patTyped_atoms {atoms P p a δ} (hp : ConAtomsIn atoms P)
      (h : PatTy P p a δ) (ht : a.AtomsIn atoms) : Tys.AtomsIn atoms δ := by
    cases h with
    | P_Wild => trivial
    | P_Var => exact ⟨ht, trivial⟩
    | P_Const => trivial
    | P_RangeInt => trivial
    | P_RangeChar => trivial
    | @P_List before rest after a δb δa hb ha hr =>
        have ht : a.AtomsIn atoms := ht
        apply tysAtoms_append (tysAtoms_append
          (patTypedList_atoms hp hb (tysAtoms_replicate ht _)) ?_)
          (patTypedList_atoms hp ha (tysAtoms_replicate ht _))
        cases rest with
        | none => trivial
        | some r => cases r <;> simp [restTys, Tys.AtomsIn, Ty.AtomsIn, ht]
    | P_Con hc hn hs =>
        exact patTypedList_atoms hp hs
          (tysAtoms_map (hp _ _ hc) (fun _ h => subst_atoms h ht (by simp)))
  theorem patTypedList_atoms {atoms P ps as δ} (hp : ConAtomsIn atoms P)
      (h : PatTys P ps as δ) (ht : Tys.AtomsIn atoms as) : Tys.AtomsIn atoms δ := by
    cases h with
    | nil => trivial
    | cons h hs => exact tysAtoms_append (patTyped_atoms hp h ht.1) (patTypedList_atoms hp hs ht.2)
end

theorem patTy_atoms {atoms P p a δ} (hp : ConAtomsIn atoms P) (ha : Ty.AtomsIn atoms a)
    (h : patTy P p a = some δ) : Tys.AtomsIn atoms δ :=
  patTyped_atoms hp (patTy_sound h) ha

def checkAlt (atoms : List Atom) (P : Release.Program) (a : Ty) (δ : List Ty) (alt : Release.Alt) : Bool :=
  match patTy P alt.pat a with
  | none => false
  | some γ => natPerm alt.slots (List.range γ.length) &&
      match selectSlots γ alt.slots with
      | none => false
      | some ds => tysEq atoms ds δ

def checkAlts (atoms : List Atom) (P : Release.Program) (alts : List Release.Alt)
    (a : Ty) (δ : List Ty) : Bool :=
  match alts with
  | [] => false
  | first :: _ => decide (δ.length = Arm.bindersOf alts) &&
      (first.slots == List.range first.pat.binders) && alts.all (checkAlt atoms P a δ)

theorem checkAlts_sound {atoms P alts a δ} (hp : ConAtomsIn atoms P)
    (ha : Ty.AtomsIn atoms a) (hd : Tys.AtomsIn atoms δ)
    (h : checkAlts atoms P alts a δ = true) : AltsTy P alts a δ := by
  cases alts with
  | nil => simp [checkAlts] at h
  | cons first rest =>
      have ⟨⟨hn, hf⟩, hall⟩ :
          (decide (δ.length = Arm.bindersOf (first :: rest)) = true ∧
            (first.slots == List.range first.pat.binders) = true) ∧
          (first :: rest).all (checkAlt atoms P a δ) = true := by
        simpa [checkAlts] using h
      refine ⟨by simp, of_decide_eq_true hn, ?_, ?_⟩
      · intro alt he
        simp only [List.head?_cons, Option.some.injEq] at he
        subst alt; exact eq_of_beq hf
      · intro alt hm
        have hc := List.all_eq_true.mp hall alt hm
        unfold checkAlt at hc
        cases hg : patTy P alt.pat a with
        | none => simp [hg] at hc
        | some γ =>
            simp only [hg] at hc
            have ⟨hs, ht⟩ := Bool.and_eq_true_iff.mp hc
            cases he : selectSlots γ alt.slots with
            | none => simp [he] at ht
            | some ds =>
                have hds := tysAtoms_selectSlots (patTy_atoms hp ha hg) he
                have eqδ := tysEq_sound hds hd (by simpa [he] using ht)
                subst ds
                exact ⟨γ, patTy_sound hg, (natPerm_spec _ _).mp hs, he⟩

/-- 最初の選択肢の束縛型を求めてから、恒等対応と残りの並べ替えを検査する。 -/
def altsTy (atoms : List Atom) (P : Release.Program) (alts : List Release.Alt) (a : Ty) :
    Option (List Ty) := do
  let first ← alts.head?
  let δ ← patTy P first.pat a
  if checkAlts atoms P alts a δ then some δ else none

theorem altsTy_sound {atoms P alts a δ} (hp : ConAtomsIn atoms P)
    (ha : Ty.AtomsIn atoms a) (h : altsTy atoms P alts a = some δ) : AltsTy P alts a δ := by
  unfold altsTy at h
  obtain ⟨first, hf, h⟩ := Option.bind_eq_some_iff.mp h
  obtain ⟨γ, hg, h⟩ := Option.bind_eq_some_iff.mp h
  split at h
  · rename_i hc
    simp only [Option.some.injEq] at h
    subst δ
    exact checkAlts_sound hp ha (patTy_atoms hp ha hg) hc
  · contradiction

/-- useful の単列への包み。選ばれない分岐の検査を追加しない。 -/
def exhaustive (D : Declarations) (ctors : DataName → List ConName)
    (a : Ty) (ps : List Release.Pat) : Bool :=
  (useful D.patternProgram ctors [a] (ps.map fun p => [p]) [.wild]).isNone

theorem exhaustive_sound {D ctors a ps} (hc : CtorsComplete D.patternProgram ctors)
    (h : exhaustive D ctors a ps = true) : Exhaustive D.patternProgram a ps := by
  have hu : useful D.patternProgram ctors [a] (ps.map fun p => [p]) [.wild] = none := by
    simpa [exhaustive] using h
  intro v hv
  exact useful_singleton_none_sound D.patternProgram ctors a ps .wild hc hu v hv rfl

def matchExhaustive (D : Declarations) (ctors : DataName → List ConName) (a : Ty) (arms : Arms) : Bool :=
  exhaustive D ctors a arms.unguardedPatterns

theorem matchExhaustive_sound {D ctors a arms} (hc : CtorsComplete D.patternProgram ctors)
    (h : matchExhaustive D ctors a arms = true) : Exhaustive D.patternProgram a arms.unguardedPatterns :=
  exhaustive_sound hc h

def tryResultExhaustive (D : Declarations) (ctors : DataName → List ConName)
    (d : DataName) (t errTy : Ty) (ok err : ConName) : Bool :=
  exhaustive D ctors (.data d [t, errTy]) [.con ok [.var], .con err [.var]]

theorem tryResultExhaustive_sound {D ctors d t errTy ok err}
    (hc : CtorsComplete D.patternProgram ctors)
    (h : tryResultExhaustive D ctors d t errTy ok err = true) :
    Exhaustive D.patternProgram (.data d [t, errTy]) [.con ok [.var], .con err [.var]] :=
  exhaustive_sound hc h

def tryOptionExhaustive (D : Declarations) (ctors : DataName → List ConName)
    (d : DataName) (t : Ty) (someCon noneCon : ConName) : Bool :=
  exhaustive D ctors (.data d [t]) [.con someCon [.var], .con noneCon []]

theorem tryOptionExhaustive_sound {D ctors d t someCon noneCon}
    (hc : CtorsComplete D.patternProgram ctors)
    (h : tryOptionExhaustive D ctors d t someCon noneCon = true) :
    Exhaustive D.patternProgram (.data d [t]) [.con someCon [.var], .con noneCon []] :=
  exhaustive_sound hc h

def bindingExhaustive (D : Declarations) (ctors : DataName → List ConName) (a : Ty) (p : Pattern) : Bool :=
  irrefutable D.patternProgram ctors a p.toCore

theorem bindingExhaustive_sound {D ctors a p} (hc : CtorsComplete D.patternProgram ctors)
    (h : bindingExhaustive D ctors a p = true) : Exhaustive D.patternProgram a [p.toCore] :=
  irrefutable_sound D.patternProgram ctors a p.toCore hc h

def recordUpdateExhaustive (D : Declarations) (ctors : DataName → List ConName)
    (cd : ConDecl) (ts : List Ty) (c : ConName) (n : Nat) (positions : List Nat) : Bool :=
  irrefutable D.patternProgram ctors (.data cd.data ts) (recordUpdatePattern c n positions)

theorem recordUpdateExhaustive_sound {D ctors cd ts c n positions}
    (hc : CtorsComplete D.patternProgram ctors)
    (h : recordUpdateExhaustive D ctors cd ts c n positions = true) :
    Exhaustive D.patternProgram (.data cd.data ts) [recordUpdatePattern c n positions] :=
  irrefutable_sound D.patternProgram ctors (.data cd.data ts) (recordUpdatePattern c n positions) hc h

end Benitoite.Surface.CheckTools
