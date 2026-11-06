import Benitoite.Release.Refinement.Surface.CheckArguments
import Benitoite.Release.Refinement.Surface.CheckBuiltinSource
import Benitoite.Release.Refinement.Surface.CheckOpenFormation
import Benitoite.Release.Refinement.Surface.CheckOpenArgumentLeaves
import Benitoite.Release.Refinement.Surface.CheckOpenRangeSupport

/-! # 範囲文脈の辞書と実引数の有限な検査 -/
noncomputable section

namespace Benitoite.Release.Refinement.Surface.CheckOpenArguments
open CheckArguments CheckCompare CheckSubtyping
open Check (BuiltinSource)

private theorem shift_support {s : List Atom} {a : Ty} {k c : Nat} (h : a.Support (· ∈ s)) :
    (a.shiftV k c).Support (· ∈ s) := (Ty.support_shiftV_iff _ _ _ _).mpr h

private theorem const_type_support (s : List Atom) (c : Const) : c.type.Support (· ∈ s) := by
  cases c <;> trivial

mutual
  /-- 辞書の各構成子を、期待される型に照合する。 -/
  def dict (q : CheckFormation.Input) (D : Declarations) (builtinSource : BuiltinSource) (sat : SatDec)
      (C : TypeCtx) (Γ : Ctx) (path : List Nat) : DictEv → Ty → DictGuide → Bool
    | .local j, a, .local => match Γ[j]? with
      | some (some (.dict cl t)) => rawTyEq q.atoms (.dict cl t) a
      | _ => false
    | .clause scope i depth, a, .clause => match Γ[depth + scope.slot i]? with
      | some (some (.dict cl t)) => rawTyEq q.atoms (.dict cl t) a
      | _ => false
    | .impl i ts ds, a, .impl gs => match D.impls i with
      | none => false
      | some d =>
        let expected := Ty.dict d.cls (CheckFormation.substTy q ts [] d.target)
        (rawTyEq q.atoms expected a &&
          (satAll q builtinSource sat C ts d.tparams &&
            (CheckOpenFormation.annotations q q.rangeKinds D.core C Γ (path ++ [0]) ts &&
              (CheckFormation.argsKinded q D.core C ts (List.replicate d.tparams.length .value) &&
                ((d.dictTys.all (CheckFormation.wfTy q 0 d.tparams.length 0) &&
                  CheckFormation.wfTy q 0 d.tparams.length 0 d.target) &&
                  (dicts q D builtinSource sat C Γ (path ++ [1]) ds (d.dictTys.map (CheckFormation.substTy q ts [])) gs &&
                    CheckOpenFormation.annotation q q.rangeKinds D.core C Γ (path ++ [2]) expected)))))) &&
          OpenRangeFormationCheck.ty q.atoms 0 d.target
    | .super d cl, a, .super owner t g => match D.classes owner with
      | none => false
      | some cd => rawTyEq q.atoms (.dict cl t) a &&
          (dict q D builtinSource sat C Γ (path ++ [0]) d (.dict owner t) g &&
            (decide (cl ∈ cd.supers) && CheckOpenFormation.annotation q q.rangeKinds D.core C Γ (path ++ [1]) t))
    | _, _, _ => false

  def dicts (q : CheckFormation.Input) (D : Declarations) (builtinSource : BuiltinSource) (sat : SatDec)
      (C : TypeCtx) (Γ : Ctx) (path : List Nat) : List DictEv → List Ty → List DictGuide → Bool
    | [], [], [] => true
    | d :: ds, a :: as, g :: gs => dict q D builtinSource sat C Γ (path ++ [0]) d a g &&
        dicts q D builtinSource sat C Γ (path ++ [1]) ds as gs
    | _, _, _ => false
end

private theorem substTys_support {q ts as} (ht : Ty.SupportList (· ∈ q.atoms) ts)
    (ha : Ty.SupportList (· ∈ q.atoms) as) :
    Ty.SupportList (· ∈ q.atoms) (as.map (CheckFormation.substTy q ts [])) := by
  apply Ty.SupportList.iff.mpr
  intro a ha'
  obtain ⟨b, hb, rfl⟩ := List.mem_map.mp ha'
  exact CheckFormation.substTy_support (Ty.SupportList.iff.mp ha b hb) ht (by simp)

mutual
  theorem dict_sound {q : CheckFormation.Input} {D : Declarations} {builtinSource : BuiltinSource} {sat C Γ path d a g} (hq : q.Sound D.core)
      (hD : TableSupport q.atoms D) (hsat : SatSound builtinSource.builtins sat)
      (hΓ : CheckFormation.CtxSupport q.atoms Γ) (hd : DictSupport q.atoms d)
      (ha : a.Support (· ∈ q.atoms)) (hg : g.Support q.atoms)
      (h : dict q D builtinSource sat C Γ path d a g = true) : OpenSurface.DictEv.HasType D builtinSource.builtins q.rangeKinds C Γ d a := by
    cases d with
    | «local» j =>
      cases g <;> try cases h
      simp only [dict] at h
      split at h
      · rename_i cl t hj
        have he := (rawTyEq_spec (hΓ _ _ hj) ha).mp h
        rw [← he]
        exact .local hj
      · cases h
    | clause scope i depth =>
      cases g <;> try cases h
      simp only [dict] at h
      split at h
      · rename_i cl t hj
        have he := (rawTyEq_spec (hΓ _ _ hj) ha).mp h
        rw [← he]
        exact .clause hj
      · cases h
    | impl i ts ds =>
      cases g <;> try cases h
      rename_i gs
      simp only [dict] at h
      split at h
      · cases h
      · rename_i id hi
        have hpair := Bool.and_eq_true_iff.mp h
        have hclosed := hpair.2
        have h := hpair.1
        simp only [Bool.and_eq_true] at h
        have hid := hD.impls i id hi
        have htarget := CheckFormation.substTy_support (q := q) (ts := ts) (es := []) hid.2 hd.1 (by simp)
        have he := (rawTyEq_spec (a := .dict id.cls (CheckFormation.substTy q ts [] id.target)) htarget ha).mp h.1
        rw [← he]
        have hsub : ∀ b ∈ id.dictTys, CheckFormation.substTy q ts [] b = b.subst ts [] :=
          fun b hb => CheckFormation.substTy_eq (Ty.SupportList.iff.mp hid.1 b hb) hd.1 (by simp)
        have hdts : id.dictTys.map (CheckFormation.substTy q ts []) = id.dictTys.map (Ty.subst ts []) :=
          List.map_congr_left hsub
        have hdt := dicts_sound hq hD hsat hΓ hd.2 (substTys_support hd.1 hid.1) hg h.2.2.2.2.2.1
        rw [hdts] at hdt
        have hannot := CheckOpenFormation.annotation_sound (a := .dict id.cls (CheckFormation.substTy q ts [] id.target)) hq hΓ htarget h.2.2.2.2.2.2
        rw [CheckFormation.substTy_eq hid.2 hd.1 (by simp)] at hannot ⊢
        refine .impl hi (satAll_sound hsat hd.1 h.2.1)
          (CheckOpenFormation.annotations_sound hq hΓ hd.1 h.2.2.1)
          (CheckFormation.argsKinded_sound hq.ctors h.2.2.2.1) ?_
          (CheckFormation.wfTy_sound hid.2 h.2.2.2.2.1.2)
          (OpenRangeFormationCheck.ty_sound hid.2 hclosed) hdt hannot
        intro b hb
        exact CheckFormation.wfTy_sound (Ty.SupportList.iff.mp hid.1 b hb)
          (List.all_eq_true.mp h.2.2.2.2.1.1 b hb)
    | super d cl =>
      cases g <;> try cases h
      rename_i owner t g
      simp only [dict] at h
      split at h
      · cases h
      · rename_i cd hc
        simp only [Bool.and_eq_true, decide_eq_true_eq] at h
        have he := (rawTyEq_spec (a := .dict cl t) hg.1 ha).mp h.1
        rw [← he]
        exact .super (dict_sound hq hD hsat hΓ hd hg.1 hg.2 h.2.1) hc h.2.2.1
          (CheckOpenFormation.annotation_sound hq hΓ hg.1 h.2.2.2).declared

  theorem dicts_sound {q : CheckFormation.Input} {D : Declarations} {builtinSource : BuiltinSource} {sat C Γ path ds as gs} (hq : q.Sound D.core)
      (hD : TableSupport q.atoms D) (hsat : SatSound builtinSource.builtins sat)
      (hΓ : CheckFormation.CtxSupport q.atoms Γ) (hd : DictsSupport q.atoms ds)
      (ha : Ty.SupportList (· ∈ q.atoms) as) (hg : DictGuidesSupport q.atoms gs)
      (h : dicts q D builtinSource sat C Γ path ds as gs = true) : OpenSurface.DictEv.HasTypes D builtinSource.builtins q.rangeKinds C Γ ds as := by
    cases ds with
    | nil => cases as <;> cases gs <;> first | exact .nil | cases h
    | cons d ds =>
      cases as with
      | nil => cases h
      | cons a as =>
        cases gs with
        | nil => cases h
        | cons g gs =>
          have hh := Bool.and_eq_true_iff.mp h
          exact .cons (dict_sound hq hD hsat hΓ hd.1 ha.1 hg.1 hh.1)
            (dicts_sound hq hD hsat hΓ hd.2 ha.2 hg.2 hh.2)
end

mutual
  private theorem dict_value_support {s d} (hd : DictSupport s d) (k : Nat) :
      ValueSupport s (d.toVal.rename (· + k)) := by
    cases d with
    | «local» _ | clause _ _ _ => trivial
    | super d cl => exact dict_value_support (d := d) hd k
    | impl i ts ds =>
      refine ⟨?_, dict_values_support hd.2 k⟩
      apply Ty.SupportList.iff.mpr
      intro a ha
      obtain ⟨b, hb, rfl⟩ := List.mem_map.mp ha
      have h := shift_support (k := k) (c := 0) (Ty.SupportList.iff.mp hd.1 b hb)
      have he : renameTy (· + k) b = b.shiftV k 0 := by
        have hi : shiftIndex k 0 = (· + k) := by funext i; simp [shiftIndex]
        rw [← hi]
        exact (Ty.shiftV_eq_renameTy b k 0).symm
      rw [he]
      exact h
  termination_by sizeOf d
  decreasing_by
    all_goals
      subst_vars
      simp_wf
      omega
  private theorem dict_values_support {s ds} (hd : DictsSupport s ds) (k : Nat) :
      ValuesSupport s (Val.renameList (· + k) (DictEv.toValList ds)) := by
    cases ds with
    | nil => trivial
    | cons d ds => exact ⟨dict_value_support (d := d) hd.1 k, dict_values_support (ds := ds) hd.2 k⟩
  termination_by sizeOf ds
  decreasing_by
    all_goals
      subst_vars
      simp_wf
      omega
end

mutual
  def arg (q : CheckFormation.Input) (D : Declarations) (builtinSource : BuiltinSource) (sat : SatDec)
      (C : TypeCtx) (Γ0 : Ctx) (k : Nat) (Γ : Ctx) (Φ : List Pred) (limit : Nat) (path : List Nat) :
      Val → Ty → ArgGuide → Bool
    | .var j, a, .var => match Γ[j]? with
      | some (some b) => rawTyEq q.atoms b a && decide (Ordinary b)
      | _ => false
    | v, a, .dictionary d b g => valueEq q.atoms v (d.toVal.rename (· + k)) &&
        (rawTyEq q.atoms (b.shiftV k 0) a && dict q D builtinSource sat C Γ0 path d b g)
    | .const c, a, .const => rawTyEq q.atoms c.type a && constOK builtinSource.builtins c
    | .list vs, .list a, .list gs => CheckOpenFormation.annotation q q.rangeKinds D.core C Γ path a &&
        elems q D builtinSource sat C Γ0 k Γ Φ limit (path ++ [0]) vs a gs
    | v, a, .refine b p sort proof g => match v.toTerm? with
      | none => false
      | some t => rawTyEq q.atoms (.refined b p) a &&
          (arg q D builtinSource sat C Γ0 k Γ Φ limit (path ++ [0]) v b g &&
            (decide (b.HasSort sort) &&
              (decide (p.Sorted Γ (some b)) &&
                (decide (p.WF (Γ.length + 1)) &&
                  (proof.check limit (Γ.facts ++ Φ) (p.open t) &&
                    (CheckOpenFormation.annotation q q.rangeKinds D.core C Γ (path ++ [1]) b &&
                      CheckFormation.declaredPred q D.core C Γ (some b) (path ++ [2]) p))))))
    | _, _, _ => false
  def elems (q : CheckFormation.Input) (D : Declarations) (builtinSource : BuiltinSource) (sat : SatDec)
      (C : TypeCtx) (Γ0 : Ctx) (k : Nat) (Γ : Ctx) (Φ : List Pred) (limit : Nat) (path : List Nat) :
      List Val → Ty → List ElemGuide → Bool
    | [], _, [] => true
    | v :: vs, a, .mk b g c :: gs => arg q D builtinSource sat C Γ0 k Γ Φ limit (path ++ [0]) v b g &&
        (LeCertificate.checkAs q.atoms D.core Γ Φ limit b a c && elems q D builtinSource sat C Γ0 k Γ Φ limit (path ++ [1]) vs a gs)
    | _, _, _ => false
end

mutual
  theorem arg_sound {q : CheckFormation.Input} {D : Declarations} {builtinSource : BuiltinSource} {sat C Γ0 k Γ Φ limit path v a g} (hq : q.Sound D.core)
      (hD : TableSupport q.atoms D) (hsat : SatSound builtinSource.builtins sat)
      (hΓ0 : CheckFormation.CtxSupport q.atoms Γ0) (hΓ : CheckFormation.CtxSupport q.atoms Γ)
      (hv : ValueSupport q.atoms v) (ha : a.Support (· ∈ q.atoms)) (hg : g.Support q.atoms)
      (h : arg q D builtinSource sat C Γ0 k Γ Φ limit path v a g = true) : OpenSurface.ArgVal D builtinSource.builtins q.rangeKinds C Γ0 k Γ Φ v a := by
    cases g with
    | var =>
      cases v <;> try cases h
      rename_i j
      simp only [arg] at h
      split at h
      · rename_i b hj
        have hh := Bool.and_eq_true_iff.mp h
        have he := (rawTyEq_spec (hΓ _ _ hj) ha).mp hh.1
        rw [← he]
        exact .var hj (of_decide_eq_true hh.2)
      · cases h
    | dictionary d b g =>
      simp only [arg, Bool.and_eq_true] at h
      have he := valueEq_sound hv (dict_value_support hg.1 k) h.1
      have ht := (rawTyEq_spec (shift_support hg.2.1) ha).mp h.2.1
      rw [he, ← ht]
      exact .dict (dict_sound hq hD hsat hΓ0 hg.1 hg.2.1 hg.2.2 h.2.2)
    | const =>
      cases v <;> try cases h
      rename_i c
      have hh := Bool.and_eq_true_iff.mp h
      have he := (rawTyEq_spec (const_type_support _ c) ha).mp hh.1
      rw [← he]
      exact .const (constOK_sound hh.2)
    | list gs =>
      cases v <;> try cases h
      rename_i vs
      cases a <;> try cases h
      rename_i a
      have hh := Bool.and_eq_true_iff.mp h
      exact .list (CheckOpenFormation.annotation_sound hq hΓ ha hh.1)
        (elems_sound hq hD hsat hΓ0 hΓ hv ha hg hh.2)
    | refine b p sort proof g =>
      simp only [arg] at h
      split at h
      · cases h
      · rename_i t ht
        simp only [Bool.and_eq_true, decide_eq_true_eq] at h
        have he := (rawTyEq_spec (a := .refined b p) hg.1 ha).mp h.1
        rw [← he]
        exact .refine (arg_sound hq hD hsat hΓ0 hΓ hv hg.1 hg.2 h.2.1) ht h.2.2.1
          h.2.2.2.1 h.2.2.2.2.1 (LogicCertificate.sound h.2.2.2.2.2.1)
          (CheckOpenFormation.annotation_sound hq hΓ hg.1 h.2.2.2.2.2.2.1).declared
          (CheckFormation.declaredPred_sound hq hΓ (by intro a he; cases he; exact hg.1) h.2.2.2.2.2.2.2)
  theorem elems_sound {q : CheckFormation.Input} {D : Declarations} {builtinSource : BuiltinSource} {sat C Γ0 k Γ Φ limit path vs a gs} (hq : q.Sound D.core)
      (hD : TableSupport q.atoms D) (hsat : SatSound builtinSource.builtins sat)
      (hΓ0 : CheckFormation.CtxSupport q.atoms Γ0) (hΓ : CheckFormation.CtxSupport q.atoms Γ)
      (hv : ValuesSupport q.atoms vs) (ha : a.Support (· ∈ q.atoms)) (hg : ElemGuidesSupport q.atoms gs)
      (h : elems q D builtinSource sat C Γ0 k Γ Φ limit path vs a gs = true) : OpenSurface.ArgElems D builtinSource.builtins q.rangeKinds C Γ0 k Γ Φ vs a := by
    cases vs with
    | nil => cases gs <;> first | exact .nil | cases h
    | cons v vs =>
      cases gs with
      | nil => cases h
      | cons g gs =>
        cases g with
        | mk b g c =>
          have hh := Bool.and_eq_true_iff.mp h
          have hh' := Bool.and_eq_true_iff.mp hh.2
          exact .cons (arg_sound hq hD hsat hΓ0 hΓ hv.1 hg.1.1 hg.1.2.1 hh.1)
            (LeCertificate.checkAs_sound hg.1.1 ha hg.1.2.2 hh'.1)
            (elems_sound hq hD hsat hΓ0 hΓ hv.2 ha hg.2 hh'.2)
end

/-! ## 位置ごとの型と依存列への実引数 -/

def valsTys (q : CheckFormation.Input) (D : Declarations) (builtinSource : BuiltinSource) (sat : SatDec)
    (C : TypeCtx) (Γ0 : Ctx) (k : Nat) (Γ : Ctx) (Φ : List Pred) (limit : Nat) (path : List Nat) :
    List Val → List Ty → List ElemGuide → Bool
  | [], [], [] => true
  | v :: vs, a :: as, .mk b g c :: gs => CheckOpenFormation.annotation q q.rangeKinds D.core C Γ (path ++ [0]) a &&
      (arg q D builtinSource sat C Γ0 k Γ Φ limit (path ++ [1]) v b g &&
        (LeCertificate.checkAs q.atoms D.core Γ Φ limit b a c &&
          valsTys q D builtinSource sat C Γ0 k Γ Φ limit (path ++ [2]) vs as gs))
  | _, _, _ => false

theorem valsTys_sound {q : CheckFormation.Input} {D : Declarations} {builtinSource : BuiltinSource} {sat C Γ0 k Γ Φ limit path vs as gs} (hq : q.Sound D.core)
    (hD : TableSupport q.atoms D) (hsat : SatSound builtinSource.builtins sat)
    (hΓ0 : CheckFormation.CtxSupport q.atoms Γ0) (hΓ : CheckFormation.CtxSupport q.atoms Γ)
    (hv : ValuesSupport q.atoms vs) (ha : Ty.SupportList (· ∈ q.atoms) as)
    (hg : ElemGuidesSupport q.atoms gs)
    (h : valsTys q D builtinSource sat C Γ0 k Γ Φ limit path vs as gs = true) : OpenSurface.ValsTys D builtinSource.builtins q.rangeKinds C Γ0 k Γ Φ vs as := by
  induction vs generalizing as gs path with
  | nil => cases as <;> cases gs <;> first | exact .nil | cases h
  | cons v vs ih =>
    cases as with
    | nil => cases h
    | cons a as =>
      cases gs with
      | nil => cases h
      | cons g gs =>
        cases g with
        | mk b g c =>
          simp only [valsTys, Bool.and_eq_true] at h
          exact .cons (CheckOpenFormation.annotation_sound hq hΓ ha.1 h.1)
            (arg_sound hq hD hsat hΓ0 hΓ hv.1 hg.1.1 hg.1.2.1 h.2.1)
            (LeCertificate.checkAs_sound hg.1.1 ha.1 hg.1.2.2 h.2.2.1)
            (ih hv.2 ha.2 hg.2 h.2.2.2)

/-- 依存列は実際に渡す値で順に具体化し、最後の結果型と効果も照合する。 -/
def valsTel (q : CheckFormation.Input) (D : Declarations) (builtinSource : BuiltinSource) (sat : SatDec)
    (C : TypeCtx) (Γ0 : Ctx) (k : Nat) (Γ : Ctx) (Φ : List Pred) (limit : Nat) (path : List Nat) :
    List Val → Tel → Ty → Eff → List ElemGuide → Bool
  | [], .done a e, r, f, [] => rawTyEq q.atoms a r &&
      (rawEffEq q.atoms e f && CheckOpenFormation.annotation q q.rangeKinds D.core C Γ path (.dependentFn (.done a e)))
  | v :: vs, .param _ a rest, r, e, .mk b g c :: gs =>
      CheckOpenFormation.annotation q q.rangeKinds D.core C Γ (path ++ [0]) a &&
        (arg q D builtinSource sat C Γ0 k Γ Φ limit (path ++ [1]) v b g &&
          (LeCertificate.checkAs q.atoms D.core Γ Φ limit b a c &&
            valsTel q D builtinSource sat C Γ0 k Γ Φ limit (path ++ [2]) vs
              (CheckFormation.bindValueTel q v rest) r e gs))
  | _, _, _, _, _ => false

theorem valsTel_sound {q : CheckFormation.Input} {D : Declarations} {builtinSource : BuiltinSource} {sat C Γ0 k Γ Φ limit path vs t r e gs} (hq : q.Sound D.core)
    (hD : TableSupport q.atoms D) (hsat : SatSound builtinSource.builtins sat)
    (hΓ0 : CheckFormation.CtxSupport q.atoms Γ0) (hΓ : CheckFormation.CtxSupport q.atoms Γ)
    (hv : ValuesSupport q.atoms vs) (ht : t.Support (· ∈ q.atoms))
    (hr : r.Support (· ∈ q.atoms)) (he : e.Support (· ∈ q.atoms))
    (hg : ElemGuidesSupport q.atoms gs)
    (h : valsTel q D builtinSource sat C Γ0 k Γ Φ limit path vs t r e gs = true) : OpenSurface.ValsTel D builtinSource.builtins q.rangeKinds C Γ0 k Γ Φ vs t r e := by
  induction vs generalizing t gs path with
  | nil =>
    cases t with
    | param => cases h
    | done a f =>
      cases gs with
      | cons => cases h
      | nil =>
        simp only [valsTel, Bool.and_eq_true] at h
        have ha := (rawTyEq_spec ht.1 hr).mp h.1
        have hf := (rawEffEq_spec ht.2 he).mp h.2.1
        rw [← ha, ← hf]
        exact .done (CheckOpenFormation.annotation_sound hq hΓ ht h.2.2)
  | cons v vs ih =>
    cases t with
    | done => cases h
    | param name a rest =>
      cases gs with
      | nil => cases h
      | cons g gs =>
        cases g with
        | mk b g c =>
          simp only [valsTel, Bool.and_eq_true] at h
          have hrest := ih hv.2 (CheckFormation.bindValueTel_support ht.2) hg.2 h.2.2.2
          rw [CheckFormation.bindValueTel_eq ht.2] at hrest
          exact .param (CheckOpenFormation.annotation_sound hq hΓ ht.1 h.1)
            (arg_sound hq hD hsat hΓ0 hΓ hv.1 hg.1.1 hg.1.2.1 h.2.1)
            (LeCertificate.checkAs_sound hg.1.1 ht.1 hg.1.2.2 h.2.2.1) hrest

private def acceptHead (ok : Bool) (t : Tel) (ds : List DictEv) : Option (Tel × List DictEv) :=
  if ok then some (t, ds) else none

/-- 直接の頭を探索し、宣言から具体化した依存列と、前置する辞書の列を返す。 -/
def head (q : CheckFormation.Input) (D : Declarations) (builtinSource : BuiltinSource) (sat : SatDec)
    (admits : AdmitsDec) (admitsR : RangeAdmitsDec) (caller : List Bool)
    (C : TypeCtx) (Γ : Ctx) (path : List Nat) : Expr → HeadGuide → Option (Tel × List DictEv)
  | .funName f ts es xs, .plain => do
      let fd ← D.funs f
      let t := openRangeTel q xs fd.tel
      acceptHead ((rangeSupport q.atoms xs &&
        (rangeArguments q.rangeKinds xs fd.rangeParams &&
          (OpenRangeFormationCheck.tel q.atoms fd.rangeParams.length fd.tel &&
            CheckFormation.wfTel q fd.rangeParams.length fd.tparams.length 0 fd.tel))) && (decide (fd.dictParams = []) && (decide (NamesWF fd.coreNames fd.coreParams) &&
        (satAll q builtinSource sat C ts (TypeCtx.constraints fd.tparams) &&
          (CheckOpenAdmissible.instantiationCheck q caller C Γ.length fd.neffs fd.coreParams fd.ret fd.eff ts es &&
            CheckOpenFormation.signatureInstance q q.rangeKinds D.core C Γ path t (TypeCtx.kinds fd.tparams) ts es)))))
        (CheckFormation.instTel q t ts es) []
  | .funDicts f ts es ds _names _ps xs, .plain => do
      let fd ← D.funs f
      let t := openRangeTel q xs fd.tel
      acceptHead ((rangeSupport q.atoms xs &&
        (rangeArguments q.rangeKinds xs fd.rangeParams &&
          (OpenRangeFormationCheck.tel q.atoms fd.rangeParams.length fd.tel &&
            CheckFormation.wfTel q fd.rangeParams.length fd.tparams.length 0 fd.tel))) && (decide (fd.dictParams ≠ []) && (decide (NamesWF fd.coreNames fd.coreParams) &&
        (satAll q builtinSource sat C ts (TypeCtx.constraints fd.tparams) &&
          (CheckOpenAdmissible.instantiationCheck q caller C Γ.length fd.neffs fd.coreParams fd.ret fd.eff ts es &&
            CheckOpenFormation.signatureInstance q q.rangeKinds D.core C Γ path t (TypeCtx.kinds fd.tparams) ts es)))))
        (CheckFormation.instTel q t ts es) ds
  | .primName b ts es xs, .plain => do
      let signature ← builtinSource.builtins.sig b
      let t := openRangeTel q xs signature.tel
      acceptHead ((rangeSupport q.atoms xs &&
        (rangeArguments q.rangeKinds xs signature.rkinds &&
          (CheckOpenFormation.primScopedCheck q D.core signature &&
            ranges builtinSource admitsR b signature xs))) &&
        (decide (NamesWF signature.names signature.params) &&
          ((admits b (TypeCtx.constraints C) (ts.map (Ty.normWith q.atoms)) && typeArguments q builtinSource ts) &&
            (CheckOpenAdmissible.primitiveAdmissibleCheck q caller C Γ.length signature ts es &&
              CheckOpenFormation.signatureInstance q q.rangeKinds D.core C Γ path t (TypeCtx.kinds signature.tparams) ts es))))
        (CheckFormation.instTel q t ts es) []
  | .opName o ts, .plain => do
      let od ← D.ops o
      acceptHead ((OpenRangeFormationCheck.tel q.atoms 0 od.tel &&
        CheckFormation.wfTel q 0 od.tparams.length 0 od.tel) && (decide (od.dictParams = []) && (decide (NamesWF od.names od.params) &&
        (satAll q builtinSource sat C ts od.tparams &&
          CheckOpenFormation.signatureInstance q q.rangeKinds D.core C Γ path od.tel (List.replicate od.tparams.length .value) ts []))))
        (CheckFormation.instTel q od.tel ts []) []
  | .opDicts o ts ds _names _ps, .plain => do
      let od ← D.ops o
      acceptHead ((OpenRangeFormationCheck.tel q.atoms 0 od.tel &&
        CheckFormation.wfTel q 0 od.tparams.length 0 od.tel) && (decide (od.dictParams ≠ []) && (decide (NamesWF od.names od.params) &&
        (satAll q builtinSource sat C ts od.tparams &&
          CheckOpenFormation.signatureInstance q q.rangeKinds D.core C Γ path od.tel (List.replicate od.tparams.length .value) ts []))))
        (CheckFormation.instTel q od.tel ts []) ds
  | .methName d m ts es us _names _ps, .method owner target dg => do
      let cd ← D.classes owner
      let ms ← cd.methods m
      acceptHead ((OpenRangeFormationCheck.tel q.atoms 0 ms.tel &&
        CheckFormation.wfTel q 0 (ms.tparams.length + 1) 0 ms.tel) && (dict q D builtinSource sat C Γ (path ++ [0]) d (.dict owner target) dg &&
        (decide (NamesWF ms.names ms.params) &&
          (satAll q builtinSource sat C ts (TypeCtx.constraints ms.tparams) &&
            (CheckOpenFormation.signatureInstance q q.rangeKinds D.core C Γ (path ++ [1]) ms.tel
              (TypeCtx.kinds ms.tparams ++ [cd.argumentKind]) (ts ++ [target]) es &&
              CheckOpenAdmissible.methodRowsCheck q caller C Γ.length ms es)))))
        (CheckFormation.instTel q ms.tel (ts ++ [target]) es) us
  | .externalName f ts, .plain => do
      let d ← D.core.externalFunction f
      acceptHead ((decide (d.tparams = []) && OpenRangeFormationCheck.tel q.atoms 0 d.parameters) &&
        (decide (ts.length = d.tparams.length) &&
        (CheckFormation.argsKinded q D.core C ts d.kinds &&
          (CheckArguments.satAll q.atoms sat C ts d.tparams &&
            (CheckFormation.annotations q D.core C [] (path ++ [0]) ts &&
              CheckOpenFormation.signatureInstance q q.rangeKinds D.core C Γ (path ++ [1]) d.parameters d.kinds ts [])))))
        (CheckFormation.instTel q d.parameters ts []) []
  | _, _ => none

private theorem acceptHead_some {ok t ds u us} (h : acceptHead ok t ds = some (u, us)) :
    ok = true ∧ t = u ∧ ds = us := by
  unfold acceptHead at h
  split at h
  · cases h; exact ⟨by assumption, rfl, rfl⟩
  · cases h


/-- 開いた範囲文脈の頭は、有限の形成と許容の検査から表層の導出を返す。 -/
theorem head_sound {q : CheckFormation.Input} {D : Declarations} {builtinSource : BuiltinSource} {sat admits admitsR caller C Γ path source guide t ds}
    (hq : q.Sound D.core) (hD : HeadTableSupport q.atoms D builtinSource.builtins)
    (hsat : SatSound builtinSource.builtins sat) (hadmits : AdmitsSound builtinSource.builtins admits)
    (hadmitsR : RangeAdmitsSound builtinSource.builtins admitsR)
    (hΓ : CheckFormation.CtxSupport q.atoms Γ) (hi : HeadInputsSupport q builtinSource.builtins source)
    (hg : guide.Support q.atoms)
    (h : head q D builtinSource sat admits admitsR caller C Γ path source guide = some (t, ds)) :
    OpenSurface.CallHeadTy D builtinSource.builtins q.rangeKinds (CheckAdmissible.NoFailCtxOf caller)
      C Γ source t ds := by
  cases source <;> cases guide <;> simp only [head, reduceCtorEq] at h
  case funName.plain f ts es xs =>
    cases hf : D.funs f with
    | none => simp [hf] at h
    | some fd =>
      simp only [hf, Option.bind_eq_bind, Option.bind_some] at h
      obtain ⟨hc, rfl, rfl⟩ := acceptHead_some h
      obtain ⟨hn, hc⟩ := Bool.and_eq_true_iff.mp hc
      simp only [Bool.and_eq_true, decide_eq_true_eq] at hn hc
      have hs := hD.funs f fd hf
      have ht := openRangeTel_checked hs.2.2.2 hn.1
      rw [CheckFormation.instTel_eq ht.2 hi.1 hi.2.1, ht.1]
      have hsig := (CheckOpenFormation.signatureInstance_sound hq hΓ ht.2 hi.1 hi.2.1 hc.2.2.2.2).sound
      rw [ht.1] at hsig
      have hsraw := CheckArguments.satAll_sound hsat hi.1 (Bool.and_eq_true_iff.mp hc.2.2.1).1
      have hadm := CheckOpenAdmissible.instantiationCheck_admissible hs.1 hs.2.1 hs.2.2.1 hi.1 hi.2.1 hsraw hc.2.2.2.1
      exact .fn hf hc.1 hc.2.1 (rangeArguments_sound hn.2.1)
        (OpenRangeFormationCheck.tel_sound hs.2.2.2 hn.2.2.1)
        (CheckFormation.wfTel_sound hs.2.2.2 hn.2.2.2)
        (admissible_leaf hadm hi.1 (Bool.and_eq_true_iff.mp hc.2.2.1).2) hsig
  case funDicts.plain f ts es dictionaries names params xs =>
    cases hf : D.funs f with
    | none => simp [hf] at h
    | some fd =>
      simp only [hf, Option.bind_eq_bind, Option.bind_some] at h
      obtain ⟨hc, rfl, rfl⟩ := acceptHead_some h
      obtain ⟨hn, hc⟩ := Bool.and_eq_true_iff.mp hc
      simp only [Bool.and_eq_true, decide_eq_true_eq] at hn hc
      have hs := hD.funs f fd hf
      have ht := openRangeTel_checked hs.2.2.2 hn.1
      rw [CheckFormation.instTel_eq ht.2 hi.1 hi.2.1, ht.1]
      have hsig := (CheckOpenFormation.signatureInstance_sound hq hΓ ht.2 hi.1 hi.2.1 hc.2.2.2.2).sound
      rw [ht.1] at hsig
      have hsraw := CheckArguments.satAll_sound hsat hi.1 (Bool.and_eq_true_iff.mp hc.2.2.1).1
      have hadm := CheckOpenAdmissible.instantiationCheck_admissible hs.1 hs.2.1 hs.2.2.1 hi.1 hi.2.1 hsraw hc.2.2.2.1
      exact .fnDicts hf hc.1 hc.2.1 (rangeArguments_sound hn.2.1)
        (OpenRangeFormationCheck.tel_sound hs.2.2.2 hn.2.2.1)
        (CheckFormation.wfTel_sound hs.2.2.2 hn.2.2.2)
        (admissible_leaf hadm hi.1 (Bool.and_eq_true_iff.mp hc.2.2.1).2) hsig
  case primName.plain b ts es xs =>
    cases hb : builtinSource.builtins.sig b with
    | none => simp [hb] at h
    | some sg =>
      simp only [hb, Option.bind_eq_bind, Option.bind_some] at h
      obtain ⟨hc, rfl, rfl⟩ := acceptHead_some h
      obtain ⟨hn, hc⟩ := Bool.and_eq_true_iff.mp hc
      simp only [Bool.and_eq_true, decide_eq_true_eq] at hn hc
      have hs := hD.prims b sg hb
      have ht := openRangeTel_checked hs.2.2.2 hn.1
      have hm := hadmits b sg (TypeCtx.constraints C) (ts.map (Ty.normWith q.atoms)) hb hc.2.1.1
      have heq : ts.map (Ty.normWith q.atoms) = Ty.normTys ts := by
        rw [Ty.normTys_eq_map]
        exact List.map_congr_left (fun a ha => Ty.normWith_eq_norm q.atoms a (Ty.SupportList.iff.mp hi.1 a ha))
      rw [heq] at hm
      have hsig := (CheckOpenFormation.signatureInstance_sound hq hΓ ht.2 hi.1 hi.2.1 hc.2.2.2).sound
      rw [ht.1] at hsig
      rw [CheckFormation.instTel_eq ht.2 hi.1 hi.2.1, ht.1]
      exact .prim hb (CheckOpenFormation.primScopedCheck_sound hq hs.1 hs.2.1 hs.2.2.2 hn.2.2.1)
        (rangeArguments_sound hn.2.1) (ranges_sound hadmitsR (rangeArguments_sound hn.2.1) hn.2.2.2)
        hc.1 (primitive_leaf hb
          (CheckOpenAdmissible.primitiveAdmissibleCheck_sound hs.1 hs.2.1 hs.2.2.1 hs.2.2.2 hi.1 hi.2.1 hm hc.2.2.1)
          hi.1 hc.2.1.2) hsig
  case opName.plain o ts =>
    cases ho : D.ops o with
    | none => simp [ho] at h
    | some od =>
      simp only [ho, Option.bind_eq_bind, Option.bind_some] at h
      obtain ⟨hc, rfl, rfl⟩ := acceptHead_some h
      obtain ⟨hn, hc⟩ := Bool.and_eq_true_iff.mp hc
      simp only [Bool.and_eq_true, decide_eq_true_eq] at hn hc
      have ht := (hD.ops o od ho).2.2.2
      rw [CheckFormation.instTel_eq ht hi (by simp)]
      exact .op ho hc.1 hc.2.1
        (OpenRangeFormationCheck.tel_sound ht hn.1) (CheckFormation.wfTel_sound ht hn.2)
        (satAll_sound hsat hi hc.2.2.1)
        (CheckOpenFormation.signatureInstance_sound hq hΓ ht hi (by simp) hc.2.2.2).sound
  case opDicts.plain o ts dictionaries names params =>
    cases ho : D.ops o with
    | none => simp [ho] at h
    | some od =>
      simp only [ho, Option.bind_eq_bind, Option.bind_some] at h
      obtain ⟨hc, rfl, rfl⟩ := acceptHead_some h
      obtain ⟨hn, hc⟩ := Bool.and_eq_true_iff.mp hc
      simp only [Bool.and_eq_true, decide_eq_true_eq] at hn hc
      have ht := (hD.ops o od ho).2.2.2
      rw [CheckFormation.instTel_eq ht hi (by simp)]
      exact .opDicts ho hc.1 hc.2.1
        (OpenRangeFormationCheck.tel_sound ht hn.1) (CheckFormation.wfTel_sound ht hn.2)
        (satAll_sound hsat hi hc.2.2.1)
        (CheckOpenFormation.signatureInstance_sound hq hΓ ht hi (by simp) hc.2.2.2).sound
  case methName.method d m ts es dictionaries names params owner target dg =>
    cases hcl : D.classes owner with
    | none => simp [hcl] at h
    | some cd =>
      simp only [hcl, Option.bind_eq_bind, Option.bind_some] at h
      cases hms : cd.methods m with
      | none => simp [hms] at h
      | some ms =>
        simp only [hms, Option.bind_some] at h
        obtain ⟨hc, rfl, rfl⟩ := acceptHead_some h
        obtain ⟨hn, hc⟩ := Bool.and_eq_true_iff.mp hc
        simp only [Bool.and_eq_true, decide_eq_true_eq] at hn hc
        have hs := hD.methods owner cd m ms hcl hms
        have hts : Ty.SupportList (· ∈ q.atoms) (ts ++ [target]) := by
          apply Ty.SupportList.iff.mpr
          intro a ha
          rcases List.mem_append.mp ha with ha | ha
          · exact Ty.SupportList.iff.mp hi.2.1 a ha
          · have he : a = target := by simpa only [List.mem_singleton] using ha
            subst a; exact hg.1
        rw [CheckFormation.instTel_eq hs.2.2.2 hts hi.2.2]
        exact .meth (dict_sound hq hD.dictionaries hsat hΓ hi.1 hg.1 hg.2 hc.1) hcl hms hc.2.1
          (satAll_sound hsat hi.2.1 hc.2.2.1)
          (OpenRangeFormationCheck.tel_sound hs.2.2.2 hn.1) (CheckFormation.wfTel_sound hs.2.2.2 hn.2)
          (CheckOpenFormation.signatureInstance_sound hq hΓ hs.2.2.2 hts hi.2.2 hc.2.2.2.1).sound
          (CheckOpenAdmissible.methodRowsCheck_sound hs.1 hs.2.1 hs.2.2.1 hi.2.2 hc.2.2.2.2).sound
  case externalName.plain f ts =>
    cases hf : D.core.externalFunction f with
    | none => simp [hf] at h
    | some d =>
      simp only [hf, Option.bind_eq_bind, Option.bind_some] at h
      obtain ⟨hc, rfl, rfl⟩ := acceptHead_some h
      obtain ⟨hn, hc⟩ := Bool.and_eq_true_iff.mp hc
      simp only [Bool.and_eq_true, decide_eq_true_eq] at hn hc
      have ht := hD.externals f d hf
      rw [CheckFormation.instTel_eq ht hi (by simp)]
      exact .external hf (OpenRangeFormationCheck.tel_sound ht hn.2)
        (OpenLeafFormation.external_of_check hn.1 ⟨hc.1, CheckFormation.argsKinded_sound hq.ctors hc.2.1,
          CheckArguments.satAll_sound hsat hi hc.2.2.1,
          CheckFormation.annotations_sound hq (by intro i a h; cases h) hi hc.2.2.2.1⟩)

/-- 具体化した頭の依存列と、前置する辞書の列の支持。 -/
theorem head_result_support {q : CheckFormation.Input} {D : Declarations} {builtinSource : BuiltinSource} {sat admits admitsR caller C Γ path source guide t ds}
    (hD : HeadTableSupport q.atoms D builtinSource.builtins)
    (hi : HeadInputsSupport q builtinSource.builtins source) (hg : guide.Support q.atoms)
    (h : head q D builtinSource sat admits admitsR caller C Γ path source guide = some (t, ds)) :
    t.Support (· ∈ q.atoms) ∧ ds = headDictionaries source := by
  cases source <;> cases guide <;> simp only [head, reduceCtorEq] at h
  case funName.plain f ts es xs =>
    cases hf : D.funs f with
    | none => simp [hf] at h
    | some fd =>
      simp only [hf, Option.bind_eq_bind, Option.bind_some] at h
      obtain ⟨hc, rfl, rfl⟩ := acceptHead_some h
      have hn := Bool.and_eq_true_iff.mp hc
      have hr := (Bool.and_eq_true_iff.mp hn.1).1
      have ht := openRangeTel_checked (hD.funs f fd hf).2.2.2 hr
      exact ⟨CheckFormation.instTel_support ht.2 hi.1 hi.2.1, rfl⟩
  case funDicts.plain f ts es dictionaries names params xs =>
    cases hf : D.funs f with
    | none => simp [hf] at h
    | some fd =>
      simp only [hf, Option.bind_eq_bind, Option.bind_some] at h
      obtain ⟨hc, rfl, rfl⟩ := acceptHead_some h
      have hn := Bool.and_eq_true_iff.mp hc
      have hr := (Bool.and_eq_true_iff.mp hn.1).1
      have ht := openRangeTel_checked (hD.funs f fd hf).2.2.2 hr
      exact ⟨CheckFormation.instTel_support ht.2 hi.1 hi.2.1, rfl⟩
  case primName.plain b ts es xs =>
    cases hb : builtinSource.builtins.sig b with
    | none => simp [hb] at h
    | some sg =>
      simp only [hb, Option.bind_eq_bind, Option.bind_some] at h
      obtain ⟨hc, rfl, rfl⟩ := acceptHead_some h
      have hn := Bool.and_eq_true_iff.mp hc
      have hr := (Bool.and_eq_true_iff.mp hn.1).1
      have ht := openRangeTel_checked (hD.prims b sg hb).2.2.2 hr
      exact ⟨CheckFormation.instTel_support ht.2 hi.1 hi.2.1, rfl⟩
  case opName.plain o ts =>
    cases ho : D.ops o with
    | none => simp [ho] at h
    | some od =>
      simp only [ho, Option.bind_eq_bind, Option.bind_some] at h
      obtain ⟨_, rfl, rfl⟩ := acceptHead_some h
      exact ⟨CheckFormation.instTel_support (hD.ops o od ho).2.2.2 hi (by simp), rfl⟩
  case opDicts.plain o ts dictionaries names params =>
    cases ho : D.ops o with
    | none => simp [ho] at h
    | some od =>
      simp only [ho, Option.bind_eq_bind, Option.bind_some] at h
      obtain ⟨_, rfl, rfl⟩ := acceptHead_some h
      exact ⟨CheckFormation.instTel_support (hD.ops o od ho).2.2.2 hi (by simp), rfl⟩
  case methName.method d m ts es dictionaries names params owner target dg =>
    cases hcl : D.classes owner with
    | none => simp [hcl] at h
    | some cd =>
      simp only [hcl, Option.bind_eq_bind, Option.bind_some] at h
      cases hms : cd.methods m with
      | none => simp [hms] at h
      | some ms =>
        simp only [hms, Option.bind_some] at h
        obtain ⟨_, rfl, rfl⟩ := acceptHead_some h
        have hts : Ty.SupportList (· ∈ q.atoms) (ts ++ [target]) := by
          apply Ty.SupportList.iff.mpr
          intro a ha
          rcases List.mem_append.mp ha with ha | ha
          · exact Ty.SupportList.iff.mp hi.2.1 a ha
          · have he : a = target := by simpa only [List.mem_singleton] using ha
            subst a; exact hg.1
        exact ⟨CheckFormation.instTel_support (hD.methods owner cd m ms hcl hms).2.2.2 hts hi.2.2, rfl⟩
  case externalName.plain f ts =>
    cases hf : D.core.externalFunction f with
    | none => simp [hf] at h
    | some d =>
      simp only [hf, Option.bind_eq_bind, Option.bind_some] at h
      obtain ⟨_, rfl, rfl⟩ := acceptHead_some h
      exact ⟨CheckFormation.instTel_support (hD.externals f d hf) hi (by simp), rfl⟩

end Benitoite.Release.Refinement.Surface.CheckOpenArguments
