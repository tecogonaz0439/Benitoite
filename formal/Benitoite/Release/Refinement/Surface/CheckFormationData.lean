import Benitoite.Release.Refinement.Surface.CheckFormationBase
import Benitoite.Release.Refinement.Declared

/-! 欄の受け手の名目型を、有限の案内と宣言表で照合する。 -/
namespace Benitoite.Release.Refinement.Surface.CheckFormation
open CheckCompare

mutual
  def observationLe (q : Input) (P : Refinement.Program) : Ty → Ty → Bool
    | .data d as, .data e bs => decide (d = e) && observationArgsLe q P (P.varianceFor d as.length) as bs
    | .scoped o _ i, .opaque p j => decide (o = p) && decide (j.Covers i)
    | a, b => normTyEq q.atoms a b
  termination_by a b => sizeOf a + sizeOf b
  decreasing_by all_goals (subst_vars; simp_wf <;> omega)
  def observationArgsLe (q : Input) (P : Refinement.Program) : List Variance → List Ty → List Ty → Bool
    | [], [], [] => true
    | .covariant :: vs, a :: as, b :: bs => observationLe q P a b && observationArgsLe q P vs as bs
    | .contravariant :: vs, a :: as, b :: bs => observationLe q P b a && observationArgsLe q P vs as bs
    | .invariant :: vs, a :: as, b :: bs => normTyEq q.atoms a b && observationArgsLe q P vs as bs
    | _, _, _ => false
  termination_by _ as bs => sizeOf as + sizeOf bs
  decreasing_by all_goals (subst_vars; simp_wf <;> omega)
end

mutual
  theorem observationLe_sound {q P a b} (ha : a.Support (· ∈ q.atoms)) (hb : b.Support (· ∈ q.atoms))
      (h : observationLe q P a b = true) : Ty.LeQ P [] [] a b := by
    unfold observationLe at h
    split at h
    · rename_i d as e bs
      have hh := Bool.and_eq_true_iff.mp h
      have he : d = e := of_decide_eq_true hh.1
      subst e
      exact .data (observationArgsLe_sound ha hb hh.2)
    · rename_i o k i p j
      have hh := Bool.and_eq_true_iff.mp h
      have he : o = p := of_decide_eq_true hh.1
      subst p
      exact .trans (.scoped (of_decide_eq_true hh.2)) .scoped_forget
    · exact .convert ((normTyEq_spec ha hb).mp h)
  termination_by sizeOf a + sizeOf b
  decreasing_by all_goals (subst_vars; simp_wf <;> omega)
  theorem observationArgsLe_sound {q P vs as bs} (ha : Ty.SupportList (· ∈ q.atoms) as)
      (hb : Ty.SupportList (· ∈ q.atoms) bs) (h : observationArgsLe q P vs as bs = true) :
      TypeArgsLe P [] [] vs as bs := by
    cases vs with
    | nil => cases as <;> cases bs <;> simp only [observationArgsLe, Bool.false_eq_true] at h; exact .nil
    | cons v vs =>
      cases as with
      | nil => simp [observationArgsLe] at h
      | cons a as => cases bs with
        | nil => simp [observationArgsLe] at h
        | cons b bs =>
          cases v with
          | covariant =>
            simp only [observationArgsLe, Bool.and_eq_true] at h
            have hh := h
            exact .covariant_cons (observationLe_sound ha.1 hb.1 hh.1) (observationArgsLe_sound ha.2 hb.2 hh.2)
          | contravariant =>
            simp only [observationArgsLe, Bool.and_eq_true] at h
            have hh := h
            exact .contravariant_cons (observationLe_sound hb.1 ha.1 hh.1) (observationArgsLe_sound ha.2 hb.2 hh.2)
          | invariant =>
            simp only [observationArgsLe, Bool.and_eq_true] at h
            have hh := h
            exact .invariant_cons ((normTyEq_spec ha.1 hb.1).mp hh.1) (observationArgsLe_sound ha.2 hb.2 hh.2)
  termination_by sizeOf as + sizeOf bs
  decreasing_by all_goals (subst_vars; simp_wf <;> omega)
end

mutual
  theorem observationType_support (s : List Atom) (a : Ty) : a.observationType.Support (· ∈ s) := by
    cases a <;> simp only [Ty.observationType, Ty.Support]
    case data | tapp => exact observationTypes_support s _
    case refined a p => exact observationType_support s a
    all_goals simp [Eff.Support, Ty.SupportList]
  theorem observationTypes_support (s : List Atom) (as : List Ty) :
      Ty.SupportList (· ∈ s) (observationTypes as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨observationType_support s a, observationTypes_support s as⟩
end

def observationArgs (q : Input) (P : Refinement.Program) (d : DataName) (as bs : List Ty) : Bool :=
  observationArgsLe q P (P.varianceFor d as.length) (observationTypes as) (observationTypes bs)

theorem observationArgs_sound {q P d as bs} (h : observationArgs q P d as bs = true) :
    DataObservationLe P d as bs :=
  observationArgsLe_sound (observationTypes_support _ _) (observationTypes_support _ _) h

def substTy (q : Input) (ts : List Ty) (es : List Eff) (a : Ty) : Ty :=
  (a.rawBind (typeEnvAt 0 ts es)).normWith q.atoms

theorem rawSubst_support {q : Input} {a : Ty} {ts : List Ty} {es : List Eff} (ha : a.Support (· ∈ q.atoms))
    (ht : Ty.SupportList (· ∈ q.atoms) ts) (he : ∀ e ∈ es, e.Support (· ∈ q.atoms)) :
    (a.rawBind (typeEnvAt 0 ts es)).Support (· ∈ q.atoms) :=
  Ty.rawBind_support _ _ _ _ ha
    (typeEnvAt_support_of_imp 0 ts es (Ty.SupportList.iff.mp ht) he (fun _ h => h))

theorem substTy_eq {q : Input} {a : Ty} {ts : List Ty} {es : List Eff} (ha : a.Support (· ∈ q.atoms))
    (ht : Ty.SupportList (· ∈ q.atoms) ts) (he : ∀ e ∈ es, e.Support (· ∈ q.atoms)) :
    substTy q ts es a = a.subst ts es :=
  Ty.normWith_eq_norm q.atoms _ (rawSubst_support ha ht he)

theorem substTy_support {q : Input} {a : Ty} {ts : List Ty} {es : List Eff} (ha : a.Support (· ∈ q.atoms))
    (ht : Ty.SupportList (· ∈ q.atoms) ts) (he : ∀ e ∈ es, e.Support (· ∈ q.atoms)) :
    (substTy q ts es a).Support (· ∈ q.atoms) :=
  Ty.normWith_support q.atoms _ (rawSubst_support ha ht he)

private theorem valueEnv_support (s : List Atom) (ν : ObservationEnv) :
    SupportTransport (· ∈ s) (· ∈ s) (SubstEnv.valuesOnly ν) := by
  constructor
  · intro i; trivial
  constructor
  · intro e he; cases he
  intro a ha
  simp only [Eff.rawBind, SubstEnv.valuesOnly, instAtoms_nil, substAtoms_nil,
    rawBindTys, rowFails, List.length_nil, List.range_zero, List.filter_nil,
    List.flatMap_nil, List.append_nil, Eff.Support, Ty.SupportList, and_true]
  intro b hb
  have he : b = a := of_decide_eq_true hb
  exact he ▸ ha

/-- 評価済みの一引数を依存列へ渡す、有限の正規化を用いた具体化。 -/
def bindValueTel (q : Input) (v : Val) (t : Tel) : Tel :=
  Tel.normWith q.atoms (Tel.rawBind (Tel.argumentsEnv v) t)

theorem bindValueTel_eq {q : Input} {v : Val} {t : Tel} (ht : t.Support (· ∈ q.atoms)) :
    bindValueTel q v t = Tel.bind (Tel.argumentsEnv v) t := by
  apply Tel.normWith_eq_norm
  exact Tel.rawBind_support _ _ _ _ ht (valueEnv_support q.atoms _)

theorem bindValueTel_support {q : Input} {v : Val} {t : Tel} (ht : t.Support (· ∈ q.atoms)) :
    (bindValueTel q v t).Support (· ∈ q.atoms) := by
  have hs := Tel.rawBind_support _ _ (Tel.argumentsEnv v) t ht (valueEnv_support q.atoms _)
  unfold bindValueTel
  rw [Tel.normWith_eq_norm q.atoms _ hs]
  exact Tel.norm_support _ hs

/-- 範囲の像を具体化した後の有限支持を用いる。 -/
def instRangeTel (q : Input) (rs : List RangeExpr) (t : Tel) : Tel :=
  Tel.normWith q.atoms (Tel.rawBind (SubstEnv.rangesOnly rs) t)

theorem instRangeTel_eq {q : Input} {rs : List RangeExpr} {t : Tel}
    (ht : (Tel.rawMapRanges (rangeAt 0 rs) t).Support (· ∈ q.atoms)) :
    instRangeTel q rs t = Tel.instR rs t := by
  rw [Tel.rawMapRanges_rangesOnly] at ht
  rw [Tel.instR_eq_bind]
  exact Tel.normWith_eq_norm q.atoms _ ht

theorem instRangeTel_support {q : Input} {rs : List RangeExpr} {t : Tel}
    (ht : (Tel.rawMapRanges (rangeAt 0 rs) t).Support (· ∈ q.atoms)) :
    (instRangeTel q rs t).Support (· ∈ q.atoms) := by
  rw [Tel.rawMapRanges_rangesOnly] at ht
  unfold instRangeTel
  rw [Tel.normWith_eq_norm q.atoms _ ht]
  exact Tel.norm_support _ ht

/-- 有限の案内をそのまま証拠とせず、各変数・構成子・欄・読み替えを検査する。 -/
def dataCheck (q : Input) (P : Refinement.Program) (Γ : Ctx) (t : Term) : DataHint → Option (DataName × List Ty)
  | .var => match t with
    | .var i => match Γ[i]? with
      | some (some a) => match (a.normWith q.atoms).core with
        | .data d ts => some (d, ts)
        | _ => none
      | _ => none
    | _ => none
  | .value ts => match t with
    | .dataValue c slots => match P.cons c with
      | some cd => if cd.ntys = ts.length ∧ slots.length = cd.args.length then some (cd.data, ts) else none
      | none => none
    | _ => none
  | .field h => match t with
    | .field ref receiver =>
      match dataCheck q P Γ receiver h, P.cons ref.constructor with
      | some (d, ts), some cd => match cd.args[ref.position]? with
        | some a =>
          if d = ref.owner ∧ cd.data = ref.owner ∧ cd.ntys = ts.length then
            if wfTy q 0 cd.ntys 0 a && decide ((substTy q ts [] a).HasSort ref.result) then
              match ((substTy q ts [] a).normWith q.atoms).core with
              | .data d us => some (d, us)
              | _ => none
            else none
          else none
        | none => none
      | _, _ => none
    | _ => none
  | .widen h ts => match dataCheck q P Γ t h with
    | some (d, as) => if observationArgs q P d as ts then some (d, ts) else none
    | none => none

theorem dataCheck_sound {q P Γ t hint d ts} (hq : q.Sound P) (hΓ : CtxSupport q.atoms Γ)
    (hh : hint.Support q.atoms) (h : dataCheck q P Γ t hint = some (d, ts)) :
    Term.HasData P Γ t d ts ∧ Ty.SupportList (· ∈ q.atoms) ts := by
  induction hint generalizing t d ts with
  | var =>
    cases t <;> simp only [dataCheck, reduceCtorEq] at h
    rename_i i
    cases hi : Γ[i]? with
    | none => simp [hi] at h
    | some x => cases x with
      | none => simp [hi] at h
      | some a =>
        rw [hi] at h
        cases he : (a.normWith q.atoms).core <;> simp only [he, Option.some.injEq, Prod.mk.injEq, reduceCtorEq] at h
        rename_i e us
        obtain ⟨rfl, rfl⟩ := h
        have ha := hΓ i a hi
        have hc : a.norm.core = .data e us := by simpa only [Ty.normWith_eq_norm q.atoms a ha] using he
        exact ⟨.var hi hc, by
          have hs := (Ty.support_core_iff (· ∈ q.atoms) (a.normWith q.atoms)).mpr
            (Ty.normWith_support q.atoms a ha)
          simpa only [he, Ty.Support] using hs⟩
  | value us =>
    cases t <;> simp only [dataCheck, reduceCtorEq] at h
    rename_i c slots
    cases hc : P.cons c with
    | none => simp [hc] at h
    | some cd =>
      simp only [hc] at h
      split at h
      · rename_i hvalid
        cases h
        exact ⟨.value hc rfl hvalid.1 hvalid.2, hh⟩
      · cases h
  | field hint ih =>
    cases t <;> simp only [dataCheck, reduceCtorEq] at h
    rename_i ref receiver
    cases hr : dataCheck q P Γ receiver hint with
    | none => simp [hr] at h
    | some result =>
      obtain ⟨owner, us⟩ := result
      obtain ⟨hdata, hus⟩ := ih hh hr
      cases hc : P.cons ref.constructor with
      | none => simp [hr, hc] at h
      | some cd =>
        cases ha : cd.args[ref.position]? with
        | none => simp [hr, hc, ha] at h
        | some a =>
          simp only [hr, hc, ha] at h
          split at h
          · rename_i hvalid
            have howner : owner = ref.owner := hvalid.1
            subst owner
            split at h
            · rename_i hforms
              have hforms' := Bool.and_eq_true_iff.mp hforms
              have hs := Ty.SupportList.iff.mp (hq.fields _ _ hc) a (List.mem_of_getElem? ha)
              have hsub := substTy_eq (q := q) (es := []) hs hus (by simp)
              have hsubsup := substTy_support (q := q) (es := []) hs hus (by simp)
              cases he : ((substTy q us [] a).normWith q.atoms).core <;>
                simp only [he, Option.some.injEq, Prod.mk.injEq, reduceCtorEq] at h
              rename_i e vs
              obtain ⟨rfl, rfl⟩ := h
              have hn : (a.subst us []).norm.core = .data e vs := by
                rw [Ty.normWith_eq_norm q.atoms _ hsubsup] at he
                simpa only [hsub] using he
              exact ⟨.field hdata hc hvalid.2.1 hvalid.2.2 ha (wfTy_sound hs hforms'.1)
                (by simpa only [hsub] using of_decide_eq_true hforms'.2) hn, by
                  have hsp := (Ty.support_core_iff (· ∈ q.atoms) ((substTy q us [] a).normWith q.atoms)).mpr
                    (Ty.normWith_support q.atoms _ hsubsup)
                  simpa only [he, Ty.Support] using hsp⟩
            · cases h
          · cases h
  | widen hint us ih =>
    cases hr : dataCheck q P Γ t hint with
    | none => simp [dataCheck, hr] at h
    | some result =>
      obtain ⟨owner, vs⟩ := result
      simp only [dataCheck, hr] at h
      split at h
      · rename_i hle
        cases h
        exact ⟨.widen (ih hh.1 hr).1 (observationArgs_sound hle), hh.2⟩
      · cases h

end Benitoite.Release.Refinement.Surface.CheckFormation
