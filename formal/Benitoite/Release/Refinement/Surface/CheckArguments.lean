import Benitoite.Release.Refinement.Surface.CheckFormation
import Benitoite.Release.Refinement.Surface.CheckSubtyping
import Benitoite.Release.Refinement.Surface.CheckAdmissible
import Benitoite.Release.Refinement.Surface.Rules

/-!
# 辞書と呼出しの実引数の検査

案内に格納した中間型と子の案内を、宣言と局所の文脈、形成の検査、部分型の証明書で再検査する。
案内には型付けや含意の証明を格納しない（設計書 01-12「型の情報を付けた表層の構文と型付け」）。
-/
namespace Benitoite.Release.Refinement.Surface.CheckArguments

open CheckCompare CheckSubtyping

abbrev SatDec := List TParam → Ty → TParam → Bool

def SatSound (B : Builtins) (sat : SatDec) : Prop :=
  ∀ C a p, sat C a p = true → B.sat C a p

/-- 辞書の宣言に含まれる型の支持。型付けの正しさを含まない。 -/
structure TableSupport (s : List Atom) (D : Declarations) : Prop where
  impls : ∀ i d, D.impls i = some d →
    Ty.SupportList (· ∈ s) d.dictTys ∧ d.target.Support (· ∈ s)

mutual
  def DictSupport (s : List Atom) : DictEv → Prop
    | .local _ | .clause _ _ _ => True
    | .impl _ ts ds => Ty.SupportList (· ∈ s) ts ∧ DictsSupport s ds
    | .super d _ => DictSupport s d
  def DictsSupport (s : List Atom) : List DictEv → Prop
    | [] => True
    | d :: ds => DictSupport s d ∧ DictsSupport s ds
end

inductive DictGuide where
  | local
  | clause
  | impl (args : List DictGuide)
  | super (className : ClassName) (target : Ty) (dictionary : DictGuide)

mutual
  def DictGuide.Support (s : List Atom) : DictGuide → Prop
    | .local | .clause => True
    | .impl gs => DictGuidesSupport s gs
    | .super _ a g => a.Support (· ∈ s) ∧ g.Support s
  def DictGuidesSupport (s : List Atom) : List DictGuide → Prop
    | [] => True
    | g :: gs => g.Support s ∧ DictGuidesSupport s gs
end

def satAll (s : List Atom) (sat : SatDec) (C : TypeCtx) : List Ty → List TParam → Bool
  | [], [] => true
  | a :: as, p :: ps => sat (TypeCtx.constraints C) (a.normWith s) p && satAll s sat C as ps
  | _, _ => false

theorem satAll_sound {s sat C as ps B} (hs : SatSound B sat)
    (ha : Ty.SupportList (· ∈ s) as) (h : satAll s sat C as ps = true) : SatAll B C as ps := by
  induction as generalizing ps with
  | nil => cases ps <;> simp_all [satAll, SatAll]
  | cons a as ih =>
    cases ps with
    | nil => cases h
    | cons p ps =>
      have hh := Bool.and_eq_true_iff.mp h
      obtain ⟨hlen, hrest⟩ := ih ha.2 hh.2
      refine ⟨by simp [hlen], ?_⟩
      intro i t tp ht hp
      cases i with
      | zero =>
        simp only [List.getElem?_cons_zero, Option.some.injEq] at ht hp
        subst t; subst tp
        have hsat := hs _ _ _ hh.1
        simpa only [Ty.normWith_eq_norm s a ha.1] using hsat
      | succ i => exact hrest i t tp ht hp

private theorem shift_support {s : List Atom} {a : Ty} {k c : Nat} (h : a.Support (· ∈ s)) :
    (a.shiftV k c).Support (· ∈ s) := (Ty.support_shiftV_iff _ _ _ _).mpr h

private theorem const_type_support (s : List Atom) (c : Const) : c.type.Support (· ∈ s) := by
  cases c <;> trivial

mutual
  /-- 辞書の各構成子を、期待される型に照合する。 -/
  def dict (q : CheckFormation.Input) (D : Declarations) (B : Builtins) (sat : SatDec)
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
        rawTyEq q.atoms expected a &&
          (satAll q.atoms sat C ts d.tparams &&
            (CheckFormation.annotations q D.core C Γ (path ++ [0]) ts &&
              (CheckFormation.argsKinded q D.core C ts (List.replicate d.tparams.length .value) &&
                ((d.dictTys.all (CheckFormation.wfTy q 0 d.tparams.length 0) &&
                  CheckFormation.wfTy q 0 d.tparams.length 0 d.target) &&
                  (dicts q D B sat C Γ (path ++ [1]) ds (d.dictTys.map (CheckFormation.substTy q ts [])) gs &&
                    CheckFormation.annotation q D.core C Γ (path ++ [2]) expected)))))
    | .super d cl, a, .super owner t g => match D.classes owner with
      | none => false
      | some cd => rawTyEq q.atoms (.dict cl t) a &&
          (dict q D B sat C Γ (path ++ [0]) d (.dict owner t) g &&
            (decide (cl ∈ cd.supers) && CheckFormation.annotation q D.core C Γ (path ++ [1]) t))
    | _, _, _ => false

  def dicts (q : CheckFormation.Input) (D : Declarations) (B : Builtins) (sat : SatDec)
      (C : TypeCtx) (Γ : Ctx) (path : List Nat) : List DictEv → List Ty → List DictGuide → Bool
    | [], [], [] => true
    | d :: ds, a :: as, g :: gs => dict q D B sat C Γ (path ++ [0]) d a g &&
        dicts q D B sat C Γ (path ++ [1]) ds as gs
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
  theorem dict_sound {q D B sat C Γ path d a g} (hq : q.Sound D.core)
      (hD : TableSupport q.atoms D) (hsat : SatSound B sat)
      (hΓ : CheckFormation.CtxSupport q.atoms Γ) (hd : DictSupport q.atoms d)
      (ha : a.Support (· ∈ q.atoms)) (hg : g.Support q.atoms)
      (h : dict q D B sat C Γ path d a g = true) : DictEv.HasType D B C Γ d a := by
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
        have hannot := CheckFormation.annotation_sound (a := .dict id.cls (CheckFormation.substTy q ts [] id.target)) hq hΓ htarget h.2.2.2.2.2.2
        rw [CheckFormation.substTy_eq hid.2 hd.1 (by simp)] at hannot ⊢
        refine .impl hi (satAll_sound hsat hd.1 h.2.1)
          (CheckFormation.annotations_sound hq hΓ hd.1 h.2.2.1)
          (CheckFormation.argsKinded_sound hq.ctors h.2.2.2.1) ?_
          (CheckFormation.wfTy_sound hid.2 h.2.2.2.2.1.2) hdt hannot
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
          (CheckFormation.annotation_sound hq hΓ hg.1 h.2.2.2).declared

  theorem dicts_sound {q D B sat C Γ path ds as gs} (hq : q.Sound D.core)
      (hD : TableSupport q.atoms D) (hsat : SatSound B sat)
      (hΓ : CheckFormation.CtxSupport q.atoms Γ) (hd : DictsSupport q.atoms ds)
      (ha : Ty.SupportList (· ∈ q.atoms) as) (hg : DictGuidesSupport q.atoms gs)
      (h : dicts q D B sat C Γ path ds as gs = true) : DictEv.HasTypes D B C Γ ds as := by
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

/-! ## 実引数の値の構造の照合 -/

deriving instance DecidableEq for Const

private theorem congr2 {α β γ : Type} (f : α → β → γ) {a a' : α} {b b' : β}
    (ha : a = a') (hb : b = b') : f a b = f a' b' := by
  cases ha
  cases hb
  rfl

mutual
  /-- 実引数の案内が参照する値に現れる型の支持。 -/
  def ValueSupport (s : List Atom) : Val → Prop
    | .dict _ ts vs => Ty.SupportList (· ∈ s) ts ∧ ValuesSupport s vs
    | .list vs => ValuesSupport s vs
    | .super v _ => ValueSupport s v
    | _ => True
  def ValuesSupport (s : List Atom) : List Val → Prop
    | [] => True
    | v :: vs => ValueSupport s v ∧ ValuesSupport s vs
end

def tysEq (s : List Atom) : List Ty → List Ty → Bool
  | [], [] => true
  | a :: as, b :: bs => rawTyEq s a b && tysEq s as bs
  | _, _ => false

theorem tysEq_sound {s as bs} (ha : Ty.SupportList (· ∈ s) as) (hb : Ty.SupportList (· ∈ s) bs)
    (h : tysEq s as bs = true) : as = bs := by
  induction as generalizing bs with
  | nil => cases bs <;> first | rfl | cases h
  | cons a as ih =>
    cases bs with
    | nil => cases h
    | cons b bs =>
      have hh := Bool.and_eq_true_iff.mp h
      exact congr2 List.cons ((rawTyEq_spec ha.1 hb.1).mp hh.1) (ih ha.2 hb.2 hh.2)

mutual
  /-- 実引数の値の形を全て比較する。他の値は案内で証明しない。 -/
  def valueEq (s : List Atom) : Val → Val → Bool
    | .var i, .var j => decide (i = j)
    | .const c, .const d => decide (c = d)
    | .list vs, .list ws => valuesEq s vs ws
    | .dict i ts vs, .dict j us ws => decide (i = j) && (tysEq s ts us && valuesEq s vs ws)
    | .super v c, .super w d => decide (c = d) && valueEq s v w
    | _, _ => false
  def valuesEq (s : List Atom) : List Val → List Val → Bool
    | [], [] => true
    | v :: vs, w :: ws => valueEq s v w && valuesEq s vs ws
    | _, _ => false
end

mutual
  theorem valueEq_sound {s v w} (hv : ValueSupport s v) (hw : ValueSupport s w)
      (h : valueEq s v w = true) : v = w := by
    cases v with
    | var i =>
      cases w <;> simp only [valueEq, Bool.false_eq_true, decide_eq_true_eq] at h
      exact congrArg Val.var h
    | const c =>
      cases w <;> simp only [valueEq, Bool.false_eq_true, decide_eq_true_eq] at h
      exact congrArg Val.const h
    | list vs =>
      cases w <;> simp only [valueEq, Bool.false_eq_true] at h
      exact congrArg Val.list (valuesEq_sound hv hw h)
    | dict i ts vs =>
      cases w <;> simp only [valueEq, Bool.false_eq_true, Bool.and_eq_true, decide_eq_true_eq] at h
      obtain ⟨rfl, ht, hvw⟩ := h
      exact congr2 (Val.dict i) (tysEq_sound hv.1 hw.1 ht) (valuesEq_sound hv.2 hw.2 hvw)
    | super v cl =>
      cases w <;> simp only [valueEq, Bool.false_eq_true, Bool.and_eq_true, decide_eq_true_eq] at h
      exact congr2 Val.super (valueEq_sound hv hw h.2) h.1
    | _ => simp only [valueEq, Bool.false_eq_true] at h
  theorem valuesEq_sound {s vs ws} (hv : ValuesSupport s vs) (hw : ValuesSupport s ws)
      (h : valuesEq s vs ws = true) : vs = ws := by
    cases vs with
    | nil => cases ws <;> first | rfl | cases h
    | cons v vs =>
      cases ws with
      | nil => cases h
      | cons w ws =>
        have hh := Bool.and_eq_true_iff.mp h
        exact congr2 List.cons (valueEq_sound hv.1 hw.1 hh.1) (valuesEq_sound hv.2 hw.2 hh.2)
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

def constOK (B : Builtins) : Const → Bool
  | .integer8 n => decide (-128 ≤ n ∧ n ≤ 127)
  | .integer16 n => decide (-32768 ≤ n ∧ n ≤ 32767)
  | .integer32 n => decide (-2147483648 ≤ n ∧ n ≤ 2147483647)
  | .unsignedInteger16 n => decide (0 ≤ n ∧ n ≤ 65535)
  | .unsignedInteger32 n => decide (0 ≤ n ∧ n ≤ 4294967295)
  | .unsignedInteger64 n => decide (0 ≤ n ∧ n ≤ 18446744073709551615)
  | .byte n => decide (n ≤ 255)
  | .decimal n scale => decide (-79228162514264337593543950335 ≤ n ∧
      n ≤ 79228162514264337593543950335 ∧ scale ≤ 28)
  | .opaque o _ => (B.valKind o).isNone && (B.valContent o).isNone
  | _ => true

theorem constOK_sound {B c} (h : constOK B c = true) : ConstOK B c := by
  cases c <;> simp only [constOK, ConstOK, decide_eq_true_eq, Bool.and_eq_true,
    Option.isNone_iff_eq_none] at h ⊢ <;> first | trivial | exact h

mutual
  inductive ArgGuide where
    | var
    | dictionary (evidence : DictEv) (type : Ty) (guide : DictGuide)
    | const
    | list (elements : List ElemGuide)
    | refine (base : Ty) (predicate : Pred) (sort : «Sort») (proof : LogicCertificate) (guide : ArgGuide)
  inductive ElemGuide where
    | mk (type : Ty) (guide : ArgGuide) (subtype : LeCertificate)
end

mutual
  def ArgGuide.Support (s : List Atom) : ArgGuide → Prop
    | .var | .const => True
    | .dictionary d a g => DictSupport s d ∧ a.Support (· ∈ s) ∧ g.Support s
    | .list gs => ElemGuidesSupport s gs
    | .refine a _ _ _ g => a.Support (· ∈ s) ∧ g.Support s
  def ElemGuide.Support (s : List Atom) : ElemGuide → Prop
    | .mk a g c => a.Support (· ∈ s) ∧ g.Support s ∧ c.Supported s
  def ElemGuidesSupport (s : List Atom) : List ElemGuide → Prop
    | [] => True
    | g :: gs => g.Support s ∧ ElemGuidesSupport s gs
end

mutual
  def arg (q : CheckFormation.Input) (D : Declarations) (B : Builtins) (sat : SatDec)
      (C : TypeCtx) (Γ0 : Ctx) (k : Nat) (Γ : Ctx) (Φ : List Pred) (limit : Nat) (path : List Nat) :
      Val → Ty → ArgGuide → Bool
    | .var j, a, .var => match Γ[j]? with
      | some (some b) => rawTyEq q.atoms b a && decide (Ordinary b)
      | _ => false
    | v, a, .dictionary d b g => valueEq q.atoms v (d.toVal.rename (· + k)) &&
        (rawTyEq q.atoms (b.shiftV k 0) a && dict q D B sat C Γ0 path d b g)
    | .const c, a, .const => rawTyEq q.atoms c.type a && constOK B c
    | .list vs, .list a, .list gs => CheckFormation.annotation q D.core C Γ path a &&
        elems q D B sat C Γ0 k Γ Φ limit (path ++ [0]) vs a gs
    | v, a, .refine b p sort proof g => match v.toTerm? with
      | none => false
      | some t => rawTyEq q.atoms (.refined b p) a &&
          (arg q D B sat C Γ0 k Γ Φ limit (path ++ [0]) v b g &&
            (decide (b.HasSort sort) &&
              (decide (p.Sorted Γ (some b)) &&
                (decide (p.WF (Γ.length + 1)) &&
                  (proof.check limit (Γ.facts ++ Φ) (p.open t) &&
                    (CheckFormation.annotation q D.core C Γ (path ++ [1]) b &&
                      CheckFormation.declaredPred q D.core C Γ (some b) (path ++ [2]) p))))))
    | _, _, _ => false
  def elems (q : CheckFormation.Input) (D : Declarations) (B : Builtins) (sat : SatDec)
      (C : TypeCtx) (Γ0 : Ctx) (k : Nat) (Γ : Ctx) (Φ : List Pred) (limit : Nat) (path : List Nat) :
      List Val → Ty → List ElemGuide → Bool
    | [], _, [] => true
    | v :: vs, a, .mk b g c :: gs => arg q D B sat C Γ0 k Γ Φ limit (path ++ [0]) v b g &&
        (LeCertificate.checkAs q.atoms D.core Γ Φ limit b a c && elems q D B sat C Γ0 k Γ Φ limit (path ++ [1]) vs a gs)
    | _, _, _ => false
end

mutual
  theorem arg_sound {q D B sat C Γ0 k Γ Φ limit path v a g} (hq : q.Sound D.core)
      (hD : TableSupport q.atoms D) (hsat : SatSound B sat)
      (hΓ0 : CheckFormation.CtxSupport q.atoms Γ0) (hΓ : CheckFormation.CtxSupport q.atoms Γ)
      (hv : ValueSupport q.atoms v) (ha : a.Support (· ∈ q.atoms)) (hg : g.Support q.atoms)
      (h : arg q D B sat C Γ0 k Γ Φ limit path v a g = true) : ArgVal D B C Γ0 k Γ Φ v a := by
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
      exact .list (CheckFormation.annotation_sound hq hΓ ha hh.1)
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
          (CheckFormation.annotation_sound hq hΓ hg.1 h.2.2.2.2.2.2.1).declared
          (CheckFormation.declaredPred_sound hq hΓ (by intro a he; cases he; exact hg.1) h.2.2.2.2.2.2.2)
  theorem elems_sound {q D B sat C Γ0 k Γ Φ limit path vs a gs} (hq : q.Sound D.core)
      (hD : TableSupport q.atoms D) (hsat : SatSound B sat)
      (hΓ0 : CheckFormation.CtxSupport q.atoms Γ0) (hΓ : CheckFormation.CtxSupport q.atoms Γ)
      (hv : ValuesSupport q.atoms vs) (ha : a.Support (· ∈ q.atoms)) (hg : ElemGuidesSupport q.atoms gs)
      (h : elems q D B sat C Γ0 k Γ Φ limit path vs a gs = true) : ArgElems D B C Γ0 k Γ Φ vs a := by
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

def valsTys (q : CheckFormation.Input) (D : Declarations) (B : Builtins) (sat : SatDec)
    (C : TypeCtx) (Γ0 : Ctx) (k : Nat) (Γ : Ctx) (Φ : List Pred) (limit : Nat) (path : List Nat) :
    List Val → List Ty → List ElemGuide → Bool
  | [], [], [] => true
  | v :: vs, a :: as, .mk b g c :: gs => CheckFormation.annotation q D.core C Γ (path ++ [0]) a &&
      (arg q D B sat C Γ0 k Γ Φ limit (path ++ [1]) v b g &&
        (LeCertificate.checkAs q.atoms D.core Γ Φ limit b a c &&
          valsTys q D B sat C Γ0 k Γ Φ limit (path ++ [2]) vs as gs))
  | _, _, _ => false

theorem valsTys_sound {q D B sat C Γ0 k Γ Φ limit path vs as gs} (hq : q.Sound D.core)
    (hD : TableSupport q.atoms D) (hsat : SatSound B sat)
    (hΓ0 : CheckFormation.CtxSupport q.atoms Γ0) (hΓ : CheckFormation.CtxSupport q.atoms Γ)
    (hv : ValuesSupport q.atoms vs) (ha : Ty.SupportList (· ∈ q.atoms) as)
    (hg : ElemGuidesSupport q.atoms gs)
    (h : valsTys q D B sat C Γ0 k Γ Φ limit path vs as gs = true) : ValsTys D B C Γ0 k Γ Φ vs as := by
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
          exact .cons (CheckFormation.annotation_sound hq hΓ ha.1 h.1)
            (arg_sound hq hD hsat hΓ0 hΓ hv.1 hg.1.1 hg.1.2.1 h.2.1)
            (LeCertificate.checkAs_sound hg.1.1 ha.1 hg.1.2.2 h.2.2.1)
            (ih hv.2 ha.2 hg.2 h.2.2.2)

/-- 依存列は実際に渡す値で順に具体化し、最後の結果型と効果も照合する。 -/
def valsTel (q : CheckFormation.Input) (D : Declarations) (B : Builtins) (sat : SatDec)
    (C : TypeCtx) (Γ0 : Ctx) (k : Nat) (Γ : Ctx) (Φ : List Pred) (limit : Nat) (path : List Nat) :
    List Val → Tel → Ty → Eff → List ElemGuide → Bool
  | [], .done a e, r, f, [] => rawTyEq q.atoms a r &&
      (rawEffEq q.atoms e f && CheckFormation.annotation q D.core C Γ path (.dependentFn (.done a e)))
  | v :: vs, .param _ a rest, r, e, .mk b g c :: gs =>
      CheckFormation.annotation q D.core C Γ (path ++ [0]) a &&
        (arg q D B sat C Γ0 k Γ Φ limit (path ++ [1]) v b g &&
          (LeCertificate.checkAs q.atoms D.core Γ Φ limit b a c &&
            valsTel q D B sat C Γ0 k Γ Φ limit (path ++ [2]) vs
              (CheckFormation.bindValueTel q v rest) r e gs))
  | _, _, _, _, _ => false

theorem valsTel_sound {q D B sat C Γ0 k Γ Φ limit path vs t r e gs} (hq : q.Sound D.core)
    (hD : TableSupport q.atoms D) (hsat : SatSound B sat)
    (hΓ0 : CheckFormation.CtxSupport q.atoms Γ0) (hΓ : CheckFormation.CtxSupport q.atoms Γ)
    (hv : ValuesSupport q.atoms vs) (ht : t.Support (· ∈ q.atoms))
    (hr : r.Support (· ∈ q.atoms)) (he : e.Support (· ∈ q.atoms))
    (hg : ElemGuidesSupport q.atoms gs)
    (h : valsTel q D B sat C Γ0 k Γ Φ limit path vs t r e gs = true) : ValsTel D B C Γ0 k Γ Φ vs t r e := by
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
        exact .done (CheckFormation.annotation_sound hq hΓ ht h.2.2)
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
          exact .param (CheckFormation.annotation_sound hq hΓ ht.1 h.1)
            (arg_sound hq hD hsat hΓ0 hΓ hv.1 hg.1.1 hg.1.2.1 h.2.1)
            (LeCertificate.checkAs_sound hg.1.1 ht.1 hg.1.2.2 h.2.2.1) hrest

/-! ## 直接の呼出しの頭 -/

abbrev AdmitsDec := PrimName → List TParam → List Ty → Bool
abbrev RangeAdmitsDec := PrimName → List RangeExpr → Bool

def AdmitsSound (B : Builtins) (admits : AdmitsDec) : Prop :=
  ∀ b signature C ts, B.sig b = some signature → admits b C ts = true → signature.admits C ts

def RangeAdmitsSound (B : Builtins) (admits : RangeAdmitsDec) : Prop :=
  ∀ b rs, admits b rs = true → B.admitsR b rs

def rangeKinds : List RangeExpr → List Scope.Domain.Kind → Bool
  | [], [] => true
  | r :: rs, k :: ks => decide (r.FitsKind k) && rangeKinds rs ks
  | _, _ => false

theorem rangeKinds_sound {rs ks} (h : rangeKinds rs ks = true) :
    rs.length = ks.length ∧ ∀ (i : Nat) (r : RangeExpr) (k : Scope.Domain.Kind),
      rs[i]? = some r → ks[i]? = some k → r.FitsKind k := by
  induction rs generalizing ks with
  | nil => cases ks <;> simp_all [rangeKinds]
  | cons r rs ih =>
    cases ks with
    | nil => cases h
    | cons k ks =>
      have hh := Bool.and_eq_true_iff.mp h
      obtain ⟨hlen, hrest⟩ := ih hh.2
      refine ⟨by simp [hlen], ?_⟩
      intro i a l ha hl
      cases i with
      | zero =>
        simp only [List.getElem?_cons_zero, Option.some.injEq] at ha hl
        subst a; subst l
        exact of_decide_eq_true hh.1
      | succ i => exact hrest i a l ha hl

def rangeAdmissible (admits : RangeAdmitsDec) (b : PrimName) (s : PrimSig) (rs : List RangeExpr) : Bool :=
  rangeKinds rs s.rkinds && (rs.all (fun r => decide (r.WF ∧ r.Canonical)) &&
    (rs.all (fun r => decide (r = .absolute .top)) || admits b rs))

theorem rangeAdmissible_sound {admits B b s rs} (hs : RangeAdmitsSound B admits)
    (h : rangeAdmissible admits b s rs = true) : B.RangeAdmissible b s rs := by
  have hh := Bool.and_eq_true_iff.mp h
  have hh' := Bool.and_eq_true_iff.mp hh.2
  obtain ⟨hlen, hkinds⟩ := rangeKinds_sound hh.1
  refine ⟨hlen, hkinds, ?_, ?_⟩
  · intro r hr
    exact of_decide_eq_true (List.all_eq_true.mp hh'.1 r hr)
  · rcases Bool.or_eq_true_iff.mp hh'.2 with htop | hcustom
    · exact .inl (fun r hr => of_decide_eq_true (List.all_eq_true.mp htop r hr))
    · exact .inr (hs b rs hcustom)

def SignatureSupport (atoms : List Atom) (ps : List Ty) (r : Ty) (e : Eff) (t : Tel) : Prop :=
  Ty.SupportList (· ∈ atoms) ps ∧ r.Support (· ∈ atoms) ∧ e.Support (· ∈ atoms) ∧ t.Support (· ∈ atoms)

/-- 頭の探索で参照する署名の支持。宣言の整形式や型付けを仮定しない。 -/
structure HeadTableSupport (atoms : List Atom) (D : Declarations) (B : Builtins) : Prop where
  dictionaries : TableSupport atoms D
  funs : ∀ f fd, D.funs f = some fd → SignatureSupport atoms fd.coreParams fd.ret fd.eff fd.tel
  prims : ∀ b s, B.sig b = some s → SignatureSupport atoms s.params s.ret s.eff s.tel
  ops : ∀ o d, D.ops o = some d → SignatureSupport atoms d.params d.ret
    (.mk (fun a => match a with | .name n (.fixed .top) => decide (n = d.eff) | _ => false) []) d.tel
  methods : ∀ c cd m ms, D.classes c = some cd → cd.methods m = some ms →
    SignatureSupport atoms ms.params ms.ret ms.eff ms.tel
  externals : ∀ f d, D.core.externalFunction f = some d → d.parameters.Support (· ∈ atoms)

inductive HeadGuide where
  | plain
  | method (owner : ClassName) (target : Ty) (dictionary : DictGuide)

def HeadGuide.Support (atoms : List Atom) : HeadGuide → Prop
  | .plain => True
  | .method _ a g => a.Support (· ∈ atoms) ∧ g.Support atoms

/-- 実際に選んだ型・行・範囲の具体化の支持。範囲の全ての具体化を同じ有限一覧に入れることは要求しない。 -/
def HeadInputsSupport (q : CheckFormation.Input) (B : Builtins) : Expr → Prop
  | .funName _ ts es | .funDicts _ ts es _ _ _ =>
      Ty.SupportList (· ∈ q.atoms) ts ∧ ∀ e ∈ es, e.Support (· ∈ q.atoms)
  | .methName d _ ts es _ _ _ => DictSupport q.atoms d ∧
      Ty.SupportList (· ∈ q.atoms) ts ∧ ∀ e ∈ es, e.Support (· ∈ q.atoms)
  | .primName b ts es rs =>
      Ty.SupportList (· ∈ q.atoms) ts ∧ (∀ e ∈ es, e.Support (· ∈ q.atoms)) ∧
        ∀ s, B.sig b = some s → (Tel.rawMapRanges (rangeAt 0 (rs.map RangeExpr.absolute)) s.tel).Support (· ∈ q.atoms)
  | .opName _ ts | .opDicts _ ts _ _ _ | .externalName _ ts => Ty.SupportList (· ∈ q.atoms) ts
  | _ => True

private def acceptHead (ok : Bool) (t : Tel) (ds : List DictEv) : Option (Tel × List DictEv) :=
  if ok then some (t, ds) else none

/-- 直接の頭を探索し、宣言から具体化した依存列と、前置する辞書の列を返す。 -/
def head (q : CheckFormation.Input) (D : Declarations) (B : Builtins) (sat : SatDec)
    (admits : AdmitsDec) (admitsR : RangeAdmitsDec) (caller : List Bool)
    (C : TypeCtx) (Γ : Ctx) (path : List Nat) : Expr → HeadGuide → Option (Tel × List DictEv)
  | .funName f ts es, .plain => do
      let fd ← D.funs f
      acceptHead (decide (fd.dictParams = []) && (decide (NamesWF fd.coreNames fd.coreParams) &&
        (satAll q.atoms sat C ts (TypeCtx.constraints fd.tparams) &&
          (CheckAdmissible.instantiationCheck q caller C Γ.length fd.neffs fd.coreParams fd.ret fd.eff ts es &&
            CheckFormation.signatureInstance q D.core C Γ path fd.tel (TypeCtx.kinds fd.tparams) ts es))))
        (CheckFormation.instTel q fd.tel ts es) []
  | .funDicts f ts es ds _names _ps, .plain => do
      let fd ← D.funs f
      acceptHead (decide (fd.dictParams ≠ []) && (decide (NamesWF fd.coreNames fd.coreParams) &&
        (satAll q.atoms sat C ts (TypeCtx.constraints fd.tparams) &&
          (CheckAdmissible.instantiationCheck q caller C Γ.length fd.neffs fd.coreParams fd.ret fd.eff ts es &&
            CheckFormation.signatureInstance q D.core C Γ path fd.tel (TypeCtx.kinds fd.tparams) ts es))))
        (CheckFormation.instTel q fd.tel ts es) ds
  | .primName b ts es rs, .plain => do
      let signature ← B.sig b
      let t := CheckFormation.instRangeTel q (rs.map RangeExpr.absolute) signature.tel
      acceptHead (rangeAdmissible admitsR b signature (rs.map RangeExpr.absolute) &&
        (decide (NamesWF signature.names signature.params) &&
          (admits b (TypeCtx.constraints C) (ts.map (Ty.normWith q.atoms)) &&
            (CheckAdmissible.primitiveAdmissibleCheck q caller C Γ.length signature ts es &&
              CheckFormation.signatureInstance q D.core C Γ path t (TypeCtx.kinds signature.tparams) ts es))))
        (CheckFormation.instTel q t ts es) []
  | .opName o ts, .plain => do
      let od ← D.ops o
      acceptHead (decide (od.dictParams = []) && (decide (NamesWF od.names od.params) &&
        (satAll q.atoms sat C ts od.tparams &&
          CheckFormation.signatureInstance q D.core C Γ path od.tel (List.replicate od.tparams.length .value) ts [])))
        (CheckFormation.instTel q od.tel ts []) []
  | .opDicts o ts ds _names _ps, .plain => do
      let od ← D.ops o
      acceptHead (decide (od.dictParams ≠ []) && (decide (NamesWF od.names od.params) &&
        (satAll q.atoms sat C ts od.tparams &&
          CheckFormation.signatureInstance q D.core C Γ path od.tel (List.replicate od.tparams.length .value) ts [])))
        (CheckFormation.instTel q od.tel ts []) ds
  | .methName d m ts es us _names _ps, .method owner target dg => do
      let cd ← D.classes owner
      let ms ← cd.methods m
      acceptHead (dict q D B sat C Γ (path ++ [0]) d (.dict owner target) dg &&
        (decide (NamesWF ms.names ms.params) &&
          (satAll q.atoms sat C ts (TypeCtx.constraints ms.tparams) &&
            (CheckFormation.signatureInstance q D.core C Γ (path ++ [1]) ms.tel
              (TypeCtx.kinds ms.tparams ++ [cd.argumentKind]) (ts ++ [target]) es &&
              CheckAdmissible.methodRowsCheck q caller C Γ.length ms es))))
        (CheckFormation.instTel q ms.tel (ts ++ [target]) es) us
  | .externalName f ts, .plain => do
      let d ← D.core.externalFunction f
      acceptHead (decide (ts.length = d.tparams.length) &&
        (CheckFormation.argsKinded q D.core C ts d.kinds &&
          (satAll q.atoms sat C ts d.tparams &&
            (CheckFormation.annotations q D.core C [] (path ++ [0]) ts &&
              CheckFormation.signatureInstance q D.core C Γ (path ++ [1]) d.parameters d.kinds ts []))))
        (CheckFormation.instTel q d.parameters ts []) []
  | _, _ => none

private theorem acceptHead_some {ok t ds u us} (h : acceptHead ok t ds = some (u, us)) :
    ok = true ∧ t = u ∧ ds = us := by
  unfold acceptHead at h
  split at h
  · cases h; exact ⟨by assumption, rfl, rfl⟩
  · cases h

/-- 成功した探索は、宣言と実引数の形成・制約・範囲の許容を満たす直接の頭を返す。 -/
theorem head_sound {q D B sat admits admitsR caller C Γ path source guide t ds}
    (hq : q.Sound D.core) (hD : HeadTableSupport q.atoms D B) (hsat : SatSound B sat)
    (hadmits : AdmitsSound B admits) (hadmitsR : RangeAdmitsSound B admitsR)
    (hΓ : CheckFormation.CtxSupport q.atoms Γ) (hi : HeadInputsSupport q B source)
    (hg : guide.Support q.atoms)
    (h : head q D B sat admits admitsR caller C Γ path source guide = some (t, ds)) :
    CallHeadTy D B (CheckAdmissible.NoFailCtxOf caller) C Γ source t ds := by
  cases source <;> cases guide <;> simp only [head, reduceCtorEq] at h
  case funName.plain f ts es =>
    cases hf : D.funs f with
    | none => simp [hf] at h
    | some fd =>
      simp only [hf, Option.bind_eq_bind, Option.bind_some] at h
      obtain ⟨hc, rfl, rfl⟩ := acceptHead_some h
      simp only [Bool.and_eq_true, decide_eq_true_eq] at hc
      have hs := hD.funs f fd hf
      rw [CheckFormation.instTel_eq hs.2.2.2 hi.1 hi.2]
      exact .fn hf hc.1 hc.2.1
        (CheckAdmissible.instantiationCheck_admissible hs.1 hs.2.1 hs.2.2.1 hi.1 hi.2
          (satAll_sound hsat hi.1 hc.2.2.1) hc.2.2.2.1)
        (CheckFormation.signatureInstance_sound hq hΓ hs.2.2.2 hi.1 hi.2 hc.2.2.2.2)
  case funDicts.plain f ts es dictionaries names params =>
    cases hf : D.funs f with
    | none => simp [hf] at h
    | some fd =>
      simp only [hf, Option.bind_eq_bind, Option.bind_some] at h
      obtain ⟨hc, rfl, rfl⟩ := acceptHead_some h
      simp only [Bool.and_eq_true, decide_eq_true_eq] at hc
      have hs := hD.funs f fd hf
      rw [CheckFormation.instTel_eq hs.2.2.2 hi.1 hi.2]
      exact .fnDicts hf hc.1 hc.2.1
        (CheckAdmissible.instantiationCheck_admissible hs.1 hs.2.1 hs.2.2.1 hi.1 hi.2
          (satAll_sound hsat hi.1 hc.2.2.1) hc.2.2.2.1)
        (CheckFormation.signatureInstance_sound hq hΓ hs.2.2.2 hi.1 hi.2 hc.2.2.2.2)
  case primName.plain b ts es rs =>
    cases hb : B.sig b with
    | none => simp [hb] at h
    | some sg =>
      simp only [hb, Option.bind_eq_bind, Option.bind_some] at h
      obtain ⟨hc, rfl, rfl⟩ := acceptHead_some h
      simp only [Bool.and_eq_true, decide_eq_true_eq] at hc
      have hs := hD.prims b sg hb
      have hrs := hi.2.2 sg hb
      have ht := CheckFormation.instRangeTel_support hrs
      have hm := hadmits b sg (TypeCtx.constraints C) (ts.map (Ty.normWith q.atoms)) hb hc.2.2.1
      have heq : ts.map (Ty.normWith q.atoms) = Ty.normTys ts := by
        rw [Ty.normTys_eq_map]
        apply List.map_congr_left
        intro a ha
        exact Ty.normWith_eq_norm q.atoms a (Ty.SupportList.iff.mp hi.1 a ha)
      rw [heq] at hm
      have hsig := CheckFormation.signatureInstance_sound hq hΓ ht hi.1 hi.2.1 hc.2.2.2.2
      rw [CheckFormation.instRangeTel_eq hrs] at hsig
      rw [CheckFormation.instTel_eq ht hi.1 hi.2.1, CheckFormation.instRangeTel_eq hrs]
      exact .prim hb (rangeAdmissible_sound hadmitsR hc.1) hc.2.1
        (CheckAdmissible.primitiveAdmissibleCheck_sound hs.1 hs.2.1 hs.2.2.1 hs.2.2.2 hi.1 hi.2.1 hm hc.2.2.2.1)
        hsig
  case opName.plain o ts =>
    cases ho : D.ops o with
    | none => simp [ho] at h
    | some od =>
      simp only [ho, Option.bind_eq_bind, Option.bind_some] at h
      obtain ⟨hc, rfl, rfl⟩ := acceptHead_some h
      simp only [Bool.and_eq_true, decide_eq_true_eq] at hc
      have ht := (hD.ops o od ho).2.2.2
      rw [CheckFormation.instTel_eq ht hi (by simp)]
      exact .op ho hc.1 hc.2.1 (satAll_sound hsat hi hc.2.2.1)
        (CheckFormation.signatureInstance_sound hq hΓ ht hi (by simp) hc.2.2.2)
  case opDicts.plain o ts dictionaries names params =>
    cases ho : D.ops o with
    | none => simp [ho] at h
    | some od =>
      simp only [ho, Option.bind_eq_bind, Option.bind_some] at h
      obtain ⟨hc, rfl, rfl⟩ := acceptHead_some h
      simp only [Bool.and_eq_true, decide_eq_true_eq] at hc
      have ht := (hD.ops o od ho).2.2.2
      rw [CheckFormation.instTel_eq ht hi (by simp)]
      exact .opDicts ho hc.1 hc.2.1 (satAll_sound hsat hi hc.2.2.1)
        (CheckFormation.signatureInstance_sound hq hΓ ht hi (by simp) hc.2.2.2)
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
        simp only [Bool.and_eq_true, decide_eq_true_eq] at hc
        have hs := hD.methods owner cd m ms hcl hms
        have hts : Ty.SupportList (· ∈ q.atoms) (ts ++ [target]) := by
          apply Ty.SupportList.iff.mpr
          intro a ha
          rcases List.mem_append.mp ha with ha | ha
          · exact Ty.SupportList.iff.mp hi.2.1 a ha
          · have he : a = target := by simpa only [List.mem_singleton] using ha
            subst a
            exact hg.1
        rw [CheckFormation.instTel_eq hs.2.2.2 hts hi.2.2]
        exact .meth (dict_sound hq hD.dictionaries hsat hΓ hi.1 hg.1 hg.2 hc.1) hcl hms hc.2.1
          (satAll_sound hsat hi.2.1 hc.2.2.1)
          (CheckFormation.signatureInstance_sound hq hΓ hs.2.2.2 hts hi.2.2 hc.2.2.2.1)
          (CheckAdmissible.methodRowsCheck_sound hs.1 hs.2.1 hs.2.2.1 hi.2.2 hc.2.2.2.2)
  case externalName.plain f ts =>
    cases hf : D.core.externalFunction f with
    | none => simp [hf] at h
    | some d =>
      simp only [hf, Option.bind_eq_bind, Option.bind_some] at h
      obtain ⟨hc, rfl, rfl⟩ := acceptHead_some h
      simp only [Bool.and_eq_true, decide_eq_true_eq] at hc
      have ht := hD.externals f d hf
      rw [CheckFormation.instTel_eq ht hi (by simp)]
      exact .external hf ⟨hc.1, CheckFormation.argsKinded_sound hq.ctors hc.2.1,
        satAll_sound hsat hi hc.2.2.1,
        CheckFormation.annotations_sound hq (by intro i a h; cases h) hi hc.2.2.2.1⟩

/-- 直接の頭が前置する、ソースの辞書の列。 -/
def headDictionaries : Expr → List DictEv
  | .funDicts _ _ _ ds _ _ | .opDicts _ _ ds _ _ | .methName _ _ _ _ ds _ _ => ds
  | _ => []

/-- 探索結果の依存列は同じ有限原子に支持され、辞書はソースに書かれた列をそのまま返す。 -/
theorem head_result_support {q D B sat admits admitsR caller C Γ path source guide t ds}
    (hD : HeadTableSupport q.atoms D B) (hi : HeadInputsSupport q B source) (hg : guide.Support q.atoms)
    (h : head q D B sat admits admitsR caller C Γ path source guide = some (t, ds)) :
    t.Support (· ∈ q.atoms) ∧ ds = headDictionaries source := by
  cases source <;> cases guide <;> simp only [head, reduceCtorEq] at h
  case funName.plain f ts es =>
    cases hf : D.funs f with
    | none => simp [hf] at h
    | some fd =>
      simp only [hf, Option.bind_eq_bind, Option.bind_some] at h
      obtain ⟨_, rfl, rfl⟩ := acceptHead_some h
      exact ⟨CheckFormation.instTel_support (hD.funs f fd hf).2.2.2 hi.1 hi.2, rfl⟩
  case funDicts.plain f ts es dictionaries names params =>
    cases hf : D.funs f with
    | none => simp [hf] at h
    | some fd =>
      simp only [hf, Option.bind_eq_bind, Option.bind_some] at h
      obtain ⟨_, rfl, rfl⟩ := acceptHead_some h
      exact ⟨CheckFormation.instTel_support (hD.funs f fd hf).2.2.2 hi.1 hi.2, rfl⟩
  case primName.plain b ts es rs =>
    cases hb : B.sig b with
    | none => simp [hb] at h
    | some sg =>
      simp only [hb, Option.bind_eq_bind, Option.bind_some] at h
      obtain ⟨_, rfl, rfl⟩ := acceptHead_some h
      exact ⟨CheckFormation.instTel_support (CheckFormation.instRangeTel_support (hi.2.2 sg hb)) hi.1 hi.2.1, rfl⟩
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
            subst a
            exact hg.1
        exact ⟨CheckFormation.instTel_support (hD.methods owner cd m ms hcl hms).2.2.2 hts hi.2.2, rfl⟩
  case externalName.plain f ts =>
    cases hf : D.core.externalFunction f with
    | none => simp [hf] at h
    | some d =>
      simp only [hf, Option.bind_eq_bind, Option.bind_some] at h
      obtain ⟨_, rfl, rfl⟩ := acceptHead_some h
      exact ⟨CheckFormation.instTel_support (hD.externals f d hf) hi (by simp), rfl⟩

mutual
  private theorem emptyRanges_ty (a : Ty) : a.rawMapRanges (rangeAt 0 []) = a := by
    cases a <;> simp only [Ty.rawMapRanges, mapIx_rangeAt, RangeIx.inst_nil,
      emptyRanges_ty, emptyRanges_tel, emptyRanges_tys, emptyRanges_eff]
  private theorem emptyRanges_tel (t : Tel) : t.rawMapRanges (rangeAt 0 []) = t := by
    cases t <;> simp only [Tel.rawMapRanges, emptyRanges_ty, emptyRanges_tel, emptyRanges_eff]
  private theorem emptyRanges_tys (ts : List Ty) : mapRangesTys (rangeAt 0 []) ts = ts := by
    cases ts <;> simp only [mapRangesTys, emptyRanges_ty, emptyRanges_tys]
  private theorem emptyRanges_eff (e : Eff) : Eff.rawMapRanges (rangeAt 0 []) e = e := by
    cases e
    simp only [Eff.rawMapRanges, mapRangeAtoms_rangeAt, instAtoms_nil, emptyRanges_tys]
end

/-- 型引数だけを持つ組み込みの頭は、元の署名の支持で足りる。 -/
theorem primitive_empty_support {q D B b ts} (hD : HeadTableSupport q.atoms D B)
    (ht : Ty.SupportList (· ∈ q.atoms) ts) : HeadInputsSupport q B (.primName b ts [] []) := by
  refine ⟨ht, by simp, ?_⟩
  intro signature hs
  change (signature.tel.rawMapRanges (rangeAt 0 [])).Support (· ∈ q.atoms)
  rw [emptyRanges_tel]
  exact (hD.prims b signature hs).2.2.2

/-- 前置する辞書を k 個の束縛の下へ移しても、型の原子の支持は保たれる。 -/
theorem dicts_renamed_support {s ds} (h : DictsSupport s ds) (k : Nat) :
    ValuesSupport s (ds.map (fun d => d.toVal.rename (· + k))) := by
  induction ds with
  | nil => trivial
  | cons d ds ih => exact ⟨dict_value_support h.1 k, ih h.2⟩

/-! ## 実値の表現可能性の対照 -/

/-- 同じ期待型と案内でも、Integer8 の範囲内の値だけを受理する。 -/
example (q : CheckFormation.Input) (D : Declarations) (B : Builtins) (sat : SatDec)
    (C : TypeCtx) (Γ0 Γ : Ctx) (k limit : Nat) (Φ : List Pred) (path : List Nat) :
    arg { q with atoms := [] } D B sat C Γ0 k Γ Φ limit path (.const (.integer8 127)) (.base .integer8) .const = true ∧
      arg { q with atoms := [] } D B sat C Γ0 k Γ Φ limit path (.const (.integer8 128)) (.base .integer8) .const = false :=
  ⟨by rfl, by rfl⟩

end Benitoite.Release.Refinement.Surface.CheckArguments
