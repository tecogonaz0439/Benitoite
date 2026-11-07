import Benitoite.Release.Refinement.Surface.CheckInput
import Benitoite.Release.Refinement.Surface.CheckSingle

/-! 検査の再帰で作る文脈の有限支持と、ソースの有限な条件の判定。 -/
namespace Benitoite.Release.Refinement.Surface.Check
open CheckFormation CheckCompare CheckSubtyping

def BuilderSupport (s : List Atom) (Δ : BuilderCtx) : Prop :=
  ∀ (i : Nat) (k : BuilderKind), Δ[i]? = some (some k) → k.contents.Support (· ∈ s)

theorem type_shift_support {s : List Atom} {a : Ty} (ha : a.Support (· ∈ s)) (k c : Nat) :
    (a.shiftV k c).Support (· ∈ s) := (Ty.support_shiftV_iff _ _ _ _).mpr ha

theorem effect_shift_support {s : List Atom} {e : Eff} (he : e.Support (· ∈ s)) (k c : Nat) :
    (e.shiftV k c).Support (· ∈ s) := (Eff.support_shiftV_iff _ _ _ _).mpr he

theorem tel_shift_support {s : List Atom} {t : Tel} (ht : t.Support (· ∈ s)) (k c : Nat) :
    (Tel.shiftV k c t).Support (· ∈ s) := by
  rw [Tel.shiftV_eq_renameValues]
  exact (Tel.support_renameValues_iff _ _ _).mpr ht

theorem empty_effect_support (s : List Atom) : Eff.empty.Support (· ∈ s) :=
  ⟨(by intro a h; cases h), trivial⟩

theorem const_type_support (s : List Atom) (c : Const) : c.type.Support (· ∈ s) := by
  cases c <;> trivial

theorem CtxSupport.mem {s Γ a} (hΓ : CtxSupport s Γ) (h : some a ∈ Γ) : a.Support (· ∈ s) := by
  obtain ⟨i, hi⟩ := List.mem_iff_getElem?.mp h
  exact hΓ i a hi

theorem CtxSupport.empty (s : List Atom) : CtxSupport s [] := by intro i a h; cases i <;> cases h

theorem CtxSupport.hidden (s : List Atom) (Γ : Ctx) : CtxSupport s (Γ.map fun _ => none) := by
  intro i a h
  simp only [List.getElem?_map] at h
  cases hx : Γ[i]? <;> simp [hx] at h

theorem CtxSupport.hide {s Γ} (hΓ : CtxSupport s Γ) : CtxSupport s (hideConts Γ) := by
  intro i a hi
  simp only [hideConts, List.getElem?_map] at hi
  cases hg : Γ[i]? with
  | none => simp [hg] at hi
  | some x => cases x with
    | none => simp [hg] at hi
    | some b =>
      simp only [hg, Option.map_some] at hi
      cases hb : b.core <;> simp only [hb, Option.some.injEq, reduceCtorEq] at hi
      all_goals exact hi ▸ hΓ i b hg

theorem CtxSupport.bind {s Γ ps} (hΓ : CtxSupport s Γ) (hps : Ty.SupportList (· ∈ s) ps) :
    CtxSupport s (bindParams Γ ps) := by
  intro i a hi
  have hm := List.mem_of_getElem? hi
  simp only [bindParams, List.mem_append, List.mem_map] at hm
  rcases hm with ⟨b, hb, he⟩ | ⟨b, hb, he⟩
  · have hba : b.shiftV ps.length 0 = a := Option.some.inj he
    rw [← hba]
    exact type_shift_support (Ty.SupportList.iff.mp hps b (List.mem_reverse.mp hb)) _ _
  · cases b with
    | none => cases he
    | some b =>
      have hba : b.shiftV ps.length 0 = a := Option.some.inj he
      rw [← hba]
      exact type_shift_support (CtxSupport.mem hΓ hb) _ _

theorem CtxSupport.extendNone {s Γ} (hΓ : CtxSupport s Γ) : CtxSupport s Γ.extendNone := by
  intro i a hi
  cases i with
  | zero => cases hi
  | succ i =>
    simp only [Ctx.extendNone, List.getElem?_cons_succ, List.getElem?_map] at hi
    cases hg : Γ[i]? with
    | none => simp [hg] at hi
    | some x => cases x with
      | none => simp [hg] at hi
      | some b =>
        simp only [hg, Option.map_some, Option.some.injEq] at hi
        cases hi
        exact type_shift_support (hΓ i b hg) _ _

theorem ReturnSupport.shift {s R} (hR : ReturnSupport s R) (k : Nat) :
    ReturnSupport s (R.map (Ty.shiftV k 0)) := by
  cases R with
  | none => trivial
  | some a => exact type_shift_support hR k 0

def resultEq (q : Input) (actual : Ty) (effect : Eff) (expected : Ty) (allowed : Eff) : Bool :=
  rawTyEq q.formation.atoms actual expected && rawEffEq q.formation.atoms effect allowed

theorem resultEq_sound {q actual effect expected allowed}
    (ha : actual.Support (· ∈ q.formation.atoms)) (he : effect.Support (· ∈ q.formation.atoms))
    (hb : expected.Support (· ∈ q.formation.atoms)) (hf : allowed.Support (· ∈ q.formation.atoms))
    (h : resultEq q actual effect expected allowed = true) : actual = expected ∧ effect = allowed := by
  have hh := Bool.and_eq_true_iff.mp h
  exact ⟨(rawTyEq_spec ha hb).mp hh.1, (rawEffEq_spec he hf).mp hh.2⟩

def subtype (q : Input) (Γ : Ctx) (Φ : List Pred) (h : Hints) (i : Nat) (a b : Ty) : Bool :=
  LeCertificate.checkAs q.formation.atoms q.D.core Γ Φ q.proofSteps a b (h.le i)

theorem subtype_sound {q Γ Φ h i a b} (ha : a.Support (· ∈ q.formation.atoms))
    (hb : b.Support (· ∈ q.formation.atoms)) (hh : h.Support q.formation.atoms)
    (hc : subtype q Γ Φ h i a b = true) : Ty.LeQ q.D.core Γ Φ a b :=
  LeCertificate.checkAs_sound ha hb (hh.le i) hc

def annotation (q : Input) (C : TypeCtx) (Γ : Ctx) (path : List Nat) (a : Ty) : Bool :=
  CheckFormation.annotation q.formation q.D.core C Γ path a

theorem annotation_sound {q C Γ path a} (hq : q.Sound) (hΓ : CtxSupport q.formation.atoms Γ)
    (ha : a.Support (· ∈ q.formation.atoms)) (h : annotation q C Γ path a = true) :
    Ty.Annotation q.D.core C Γ a := CheckFormation.annotation_sound hq.formation hΓ ha h

def factsEntailed (limit : Nat) (premise goals : List Pred) : List LogicCertificate → Bool
  | [] => decide (goals = [])
  | c :: cs => match goals with
    | [] => false
    | p :: ps => c.check limit premise p && factsEntailed limit premise ps cs

theorem factsEntailed_sound {limit premise goals cs} (h : factsEntailed limit premise goals cs = true) :
    ∀ p ∈ goals, Entails premise p := by
  induction cs generalizing goals with
  | nil =>
    have he : goals = [] := by simpa only [factsEntailed, decide_eq_true_eq] using h
    subst goals
    simp
  | cons c cs ih =>
    cases goals with
    | nil => cases h
    | cons p ps =>
      have hh := Bool.and_eq_true_iff.mp h
      intro a ha
      rcases List.mem_cons.mp ha with rfl | ha
      · exact c.sound hh.1
      · exact ih hh.2 a ha

instance callOkDecidable (names : List String) (arity : Nat) (inserted : Bool)
    (labels : List (Option String)) (positions : List Nat) : Decidable (CallOk names arity inserted labels positions) := by
  unfold CallOk
  infer_instance

instance pipeValueDecidable (e : Expr) : Decidable e.PipeValue := by
  cases e <;> unfold Expr.PipeValue <;> infer_instance

instance holeConstructorDecidable (args : HoleArgs) (n : Nat) : Decidable (args.ConstructorOk n) := by
  unfold HoleArgs.ConstructorOk
  infer_instance

mutual
  instance exprExitsDecidable (e : Expr) : Decidable e.Exits := by
    cases e <;> simp only [Expr.Exits] <;> try infer_instance
    case ite c yes no => exact @instDecidableAnd _ _ (blockExitsDecidable yes) (blockExitsDecidable no)
    case elseIf c yes no => exact @instDecidableAnd _ _ (blockExitsDecidable yes) (exprExitsDecidable no)
    case paren e => exact exprExitsDecidable e
    case block body | withE o e body => exact blockExitsDecidable body
    case matchE t e arms => exact armsExitsDecidable arms
  instance blockExitsDecidable (body : Block) : Decidable body.Exits := by
    cases body <;> simp only [Block.Exits] <;> try infer_instance
    case builderBind k rest => exact blockExitsDecidable rest
    case last e => exact exprExitsDecidable e
    case seq e rest => exact @instDecidableOr _ _ (exprExitsDecidable e) (blockExitsDecidable rest)
    case bind k t e rest | discard e rest | bindPat k pat t e rest => exact blockExitsDecidable rest
  instance armsExitsDecidable (arms : Arms) : Decidable arms.Exits := by
    cases arms <;> simp only [Arms.Exits] <;> try infer_instance
    case cons alts g body rest => exact @instDecidableAnd _ _ (blockExitsDecidable body) (armsExitsDecidable rest)
end


instance formatIntegerDecidable (t : Ty) : Decidable (FormatSpec.IntegerType t) := by
  cases t <;> try (simp only [FormatSpec.IntegerType]; infer_instance)
  case base b => cases b <;> simp only [FormatSpec.IntegerType] <;> infer_instance
instance formatFractionalDecidable (t : Ty) : Decidable (FormatSpec.FractionalType t) := by
  cases t <;> try (simp only [FormatSpec.FractionalType]; infer_instance)
  case base b => cases b <;> simp only [FormatSpec.FractionalType] <;> infer_instance
instance formatSupportedDecidable (t : Ty) : Decidable (FormatSpec.SupportedType t) := by
  cases t <;> try (simp only [FormatSpec.SupportedType]; infer_instance)
  case base b => cases b <;> simp only [FormatSpec.SupportedType] <;> infer_instance
instance formatCompatibleDecidable (t : Ty) (s : FormatSpec) : Decidable (s.Compatible t) := by
  unfold FormatSpec.Compatible
  cases t <;> try (cases s.kind <;> infer_instance)
  case base b => cases b <;> cases s.kind <;> infer_instance
instance formatValidDecidable (t : Ty) (s : FormatSpec) : Decidable (s.Valid t) := by
  unfold FormatSpec.Valid
  infer_instance

def interpAllowed : List InterpPart → Bool
  | [] => true
  | .converted t :: ps => (match t with
      | .base .integer | .base .float | .base .character | .base .boolean | .base .byte | .base .decimal
      | .base .integer8 | .base .integer16 | .base .integer32 | .base .unsignedInteger16
      | .base .unsignedInteger32 | .base .unsignedInteger64 | .base .float32 => true
      | _ => false) && interpAllowed ps
  | .formatted t s :: ps => decide (s.Valid t) && interpAllowed ps
  | _ :: ps => interpAllowed ps

theorem interpAllowed_sound {ps} (h : interpAllowed ps = true) : InterpPart.Allowed ps := by
  induction ps with
  | nil => trivial
  | cons p ps ih =>
    cases p <;> simp only [interpAllowed, InterpPart.Allowed] at h ⊢
    case converted t =>
      have hh := Bool.and_eq_true_iff.mp h
      constructor
      · cases t <;> try simp_all
        case base b => cases b <;> simp_all
      · exact ih hh.2
    case formatted t spec =>
      have hh := Bool.and_eq_true_iff.mp h
      exact ⟨of_decide_eq_true hh.1, ih hh.2⟩
    all_goals exact ih h

/-- 補間の部分の判定は、条件を満たす部分の並びをすべて受け付ける。 -/
theorem interpAllowed_complete {ps} (h : InterpPart.Allowed ps) : interpAllowed ps = true := by
  induction ps with
  | nil => rfl
  | cons p ps ih =>
    cases p <;> simp only [interpAllowed, InterpPart.Allowed] at h ⊢
    case converted t =>
      refine Bool.and_eq_true_iff.mpr ⟨?_, ih h.2⟩
      rcases h.1 with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> rfl
    case formatted t spec => exact Bool.and_eq_true_iff.mpr ⟨decide_eq_true h.1, ih h.2⟩
    all_goals exact ih h

/-- 補間の部分の判定は、条件 `InterpPart.Allowed` と同値である。 -/
theorem interpAllowed_spec (ps : List InterpPart) : interpAllowed ps = true ↔ InterpPart.Allowed ps :=
  ⟨interpAllowed_sound, interpAllowed_complete⟩

/-- 文字列の式・変換・書式なしの部分の並びは、条件から判定の受理が従う。 -/
example : interpAllowed [.text "n = ", .converted (.base .integer), .stringExpr] = true :=
  (interpAllowed_spec _).mpr ⟨Or.inl rfl, trivial⟩

end Benitoite.Release.Refinement.Surface.Check
