import Benitoite.Surface.Typing
import Benitoite.Release.FiniteSupport

/-!
有限支持を明示する、表層検査器の計算できる操作。
注釈の比較は生の列の位置を保ち、計算した型だけを正規化する。
-/
namespace Benitoite.Surface.CheckTools.Finite
open Benitoite.Release

def tyEq (s : List Atom) (a b : Ty) : Bool := tyCompareWith s a b == .eq
def tysEq (s : List Atom) (as bs : List Ty) : Bool := tysCompareWith s as bs == .eq
def effEq (s : List Atom) (a b : Eff) : Bool := effCompareWith s a b == .eq

theorem tyEq_spec {s a b} (ha : Ty.Support (· ∈ s) a) (hb : Ty.Support (· ∈ s) b) :
    tyEq s a b = true ↔ a = b := by
  simp only [tyEq, compareWith_eq_compare s a b ha hb, beq_iff_eq, tyCompare_eq_iff]

theorem tysEq_spec {s as bs} (ha : Ty.SupportList (· ∈ s) as)
    (hb : Ty.SupportList (· ∈ s) bs) : tysEq s as bs = true ↔ as = bs := by
  simp only [tysEq, comparesWith_eq_compare s as bs ha hb, beq_iff_eq, tysCompare_eq_iff]

theorem effEq_spec {s a b} (ha : Eff.Support (· ∈ s) a) (hb : Eff.Support (· ∈ s) b) :
    effEq s a b = true ↔ a = b := by
  cases a with
  | mk f fs =>
    cases b with
    | mk g gs =>
      simp only [effEq, effCompareWith_eq_compare s _ _ ha hb, beq_iff_eq, effCompare]
      rw [Ordering.then_eq_eq, atomsCompare_eq_iff, tysCompare_eq_iff, EffR.mk.injEq]

/-- 正規形を前提にせず、生の等号を返す。 -/
theorem tyEq_sound {s a b} (ha : Ty.Support (· ∈ s) a) (hb : Ty.Support (· ∈ s) b)
    (h : tyEq s a b = true) : a = b := (tyEq_spec ha hb).mp h

theorem effEq_sound {s a b} (ha : Eff.Support (· ∈ s) a) (hb : Eff.Support (· ∈ s) b)
    (h : effEq s a b = true) : a = b := (effEq_spec ha hb).mp h

def applyToTy (s : List Atom) (a : Ty) (args : List Ty) : Ty :=
  (a.rawApplyTo args).normWith s
def shiftTy (s : List Atom) (k c : Nat) (a : Ty) : Ty := (a.rawShift k c).normWith s
def shiftEff (s : List Atom) (k c : Nat) (e : Eff) : Eff :=
  Eff.normWith s (Eff.rawShift k c e)
def substTyAt (s : List Atom) (c : Nat) (ts : List Ty) (es : List Eff) (a : Ty) : Ty :=
  (a.rawSubstAt c ts es).normWith s
def substEffAt (s : List Atom) (c : Nat) (ts : List Ty) (es : List Eff) (e : Eff) : Eff :=
  Eff.normWith s (Eff.rawSubstAt c ts es e)

theorem applyToTy_eq {s a args} (ha : Ty.Support (· ∈ s) a)
    (hs : Ty.SupportList (· ∈ s) args) : applyToTy s a args = a.applyTo args := by
  rw [Ty.applyTo_eq_raw_norm]
  exact Ty.normWith_eq_norm s _ (Ty.rawApplyTo_support a args ha hs)

theorem shiftTy_eq {s k c a} (ha : Ty.Support (· ∈ s) a) :
    shiftTy s k c a = a.shift k c := by
  rw [Ty.shift_eq_norm_rawShift]
  exact Ty.normWith_eq_norm s _ (Ty.rawShift_support k c a ha)

theorem shiftEff_eq {s k c e} (he : Eff.Support (· ∈ s) e) :
    shiftEff s k c e = Eff.shift k c e :=
  Eff.normWith_eq_norm s _ (Eff.rawShift_support k c e he)

theorem substTyAt_eq {s c ts es a} (ht : ∀ t ∈ ts, Ty.Support (· ∈ s) t)
    (he : ∀ e ∈ es, Eff.Support (· ∈ s) e) (ha : Ty.Support (· ∈ s) a) :
    substTyAt s c ts es a = a.substAt c ts es := by
  rw [Ty.substAt_eq_rawBind]
  have hθ := SubstEnv.at_support (c := c) ht he
  exact Ty.normWith_eq_norm s _ (Ty.rawBind_support _ hθ.1 hθ.2 a ha)

theorem substEffAt_eq {s c ts es e} (ht : ∀ t ∈ ts, Ty.Support (· ∈ s) t)
    (he : ∀ e ∈ es, Eff.Support (· ∈ s) e) (ha : Eff.Support (· ∈ s) e) :
    substEffAt s c ts es e = Eff.substAt c ts es e := by
  have hθ := SubstEnv.at_support (c := c) ht he
  exact Eff.normWith_eq_norm s _ (Eff.rawBind_support _ hθ.1 hθ.2 e ha)

/-- 支持に含まれない原子も消さずに保持する。正しい整列には支持の条件を使う。 -/
def unionEff (s : List Atom) (a b : Eff) : Eff :=
  Eff.normWith s (.mk (fun x => Eff.test a x || Eff.test b x) (a.fails ++ b.fails))

theorem union_support {s : List Atom} {a b : Eff} (ha : Eff.Support (· ∈ s) a) (hb : Eff.Support (· ∈ s) b) :
    Eff.Support (· ∈ s) (.mk (fun x => Eff.test a x || Eff.test b x) (a.fails ++ b.fails)) := by
  rw [Eff.support_iff] at ha hb
  constructor
  · intro x hx
    rcases Bool.or_eq_true_iff.mp hx with hx | hx
    · exact ha.1 x hx
    · exact hb.1 x hx
  · apply Ty.SupportList.iff.mpr
    intro t ht
    rcases List.mem_append.mp ht with ht | ht
    · exact Ty.SupportList.iff.mp ha.2 t ht
    · exact Ty.SupportList.iff.mp hb.2 t ht

/-- 最上位の原子の有限性は、和の正規化の一致には要らない。 -/
theorem unionEff_eq_of_fails {s a b} (ha : Ty.SupportList (· ∈ s) a.fails)
    (hb : Ty.SupportList (· ∈ s) b.fails) : unionEff s a b = Eff.union a b := by
  apply Eff.normWith_eq_norm_of_fails
  apply Ty.SupportList.iff.mpr
  intro t ht
  rcases List.mem_append.mp ht with ht | ht
  · exact Ty.SupportList.iff.mp ha t ht
  · exact Ty.SupportList.iff.mp hb t ht

theorem unionEff_fails_support {s a b} (ha : Ty.SupportList (· ∈ s) a.fails)
    (hb : Ty.SupportList (· ∈ s) b.fails) : Ty.SupportList (· ∈ s) (unionEff s a b).fails := by
  rw [unionEff_eq_of_fails ha hb]
  apply Eff.norm_fails_support
  apply Ty.SupportList.iff.mpr
  intro t ht
  rcases List.mem_append.mp ht with ht | ht
  · exact Ty.SupportList.iff.mp ha t ht
  · exact Ty.SupportList.iff.mp hb t ht

theorem unionEff_eq {s a b} (ha : Eff.Support (· ∈ s) a) (hb : Eff.Support (· ∈ s) b) :
    unionEff s a b = Eff.union a b := Eff.normWith_eq_norm s _ (union_support ha hb)

theorem unionEff_support {s a b} (ha : Eff.Support (· ∈ s) a) (hb : Eff.Support (· ∈ s) b) :
    Eff.Support (· ∈ s) (unionEff s a b) := by
  rw [unionEff_eq ha hb]
  exact Eff.norm_support _ (union_support ha hb)

/-- Failは型の正規形で包含を比較する。列の順序や重複には依存しない。 -/
def effSub (s : List Atom) (a b : Eff) : Bool :=
  (s.all fun x => !Eff.test a x || Eff.test b x) &&
    a.fails.all (fun t => b.fails.any fun u => tyEq s (t.normWith s) (u.normWith s))

theorem effSub_sound_of_fails {s a b} (ha : Eff.Support (· ∈ s) a) (hb : Ty.SupportList (· ∈ s) b.fails)
    (h : effSub s a b = true) : Eff.Sub a b := by
  rw [Eff.support_iff] at ha
  obtain ⟨hn, hf⟩ := Bool.and_eq_true_iff.mp h
  constructor
  · intro x hx
    have := List.all_eq_true.mp hn x (ha.1 x hx)
    simpa [hx] using this
  · rintro t ⟨u, hu, hut⟩
    obtain ⟨v, hv, hvu⟩ := List.any_eq_true.mp (List.all_eq_true.mp hf u hu)
    have huS := Ty.SupportList.iff.mp ha.2 u hu
    have hvS := Ty.SupportList.iff.mp hb v hv
    rw [Ty.normWith_eq_norm s u huS, Ty.normWith_eq_norm s v hvS] at hvu
    have heq := tyEq_sound (Ty.norm_support u huS) (Ty.norm_support v hvS) hvu
    exact ⟨v, hv, heq.symm.trans hut⟩

theorem effSub_sound {s a b} (ha : Eff.Support (· ∈ s) a) (hb : Eff.Support (· ∈ s) b)
    (h : effSub s a b = true) : Eff.Sub a b :=
  effSub_sound_of_fails ha ((Eff.support_iff b).mp hb).2 h

/-- 意味上の包含が成り立てば、列の並びによらず判定が成功する。 -/
theorem effSub_complete {s a b} (ha : Eff.Support (· ∈ s) a) (hb : Eff.Support (· ∈ s) b)
    (h : Eff.Sub a b) : effSub s a b = true := by
  rw [Eff.support_iff] at ha hb
  apply Bool.and_eq_true_iff.mpr
  constructor
  · apply List.all_eq_true.mpr
    intro x _
    cases hx : Eff.test a x
    · rfl
    · simp only [h.1 x hx, Bool.not_true, Bool.false_or]
  · apply List.all_eq_true.mpr
    intro u hu
    obtain ⟨v, hv, hnorm⟩ := h.2 u ⟨u, hu, rfl⟩
    have huS := Ty.SupportList.iff.mp ha.2 u hu
    have hvS := Ty.SupportList.iff.mp hb.2 v hv
    apply List.any_eq_true.mpr
    refine ⟨v, hv, ?_⟩
    rw [Ty.normWith_eq_norm s u huS, Ty.normWith_eq_norm s v hvS]
    exact (tyEq_spec (Ty.norm_support u huS) (Ty.norm_support v hvS)).mpr hnorm.symm

theorem effSub_spec {s a b} (ha : Eff.Support (· ∈ s) a) (hb : Eff.Support (· ∈ s) b) :
    effSub s a b = true ↔ Eff.Sub a b := ⟨effSub_sound ha hb, effSub_complete ha hb⟩

theorem tyEq_support_independent {s u a b}
    (ha : Ty.Support (· ∈ s) a) (hb : Ty.Support (· ∈ s) b)
    (ha' : Ty.Support (· ∈ u) a) (hb' : Ty.Support (· ∈ u) b) :
    tyEq s a b = tyEq u a b := congrArg (· == Ordering.eq)
      (compareWith_support_independent ha hb ha' hb')

theorem effSub_support_independent {s u a b}
    (ha : Eff.Support (· ∈ s) a) (hb : Eff.Support (· ∈ s) b)
    (ha' : Eff.Support (· ∈ u) a) (hb' : Eff.Support (· ∈ u) b) :
    effSub s a b = effSub u a b := by
  have h : effSub s a b = true ↔ effSub u a b = true :=
    (effSub_spec ha hb).trans (effSub_spec ha' hb').symm
  cases hs : effSub s a b <;> cases hu : effSub u a b <;> simp_all

def tyLe (s : List Atom) (a b : Ty) : Bool :=
  match a, b with
  | .fn ns ps r e, .fn ms qs t f => (ns == ms) && tysEq s ps qs && tyEq s r t && effSub s e f
  | _, _ => tyEq s a b

theorem tyLe_sound {s a b} (ha : Ty.Support (· ∈ s) a) (hb : Ty.Support (· ∈ s) b)
    (h : tyLe s a b = true) : Ty.Le a b := by
  cases a <;> cases b <;> try exact Or.inl (tyEq_sound ha hb h)
  rename_i ns ps r e ms qs t f
  simp only [tyLe, Bool.and_eq_true_iff] at h
  rcases h with ⟨⟨⟨hn, hp⟩, hr⟩, he⟩
  have hn := eq_of_beq hn
  have hp := (tysEq_spec ha.1 hb.1).mp hp
  have hr := tyEq_sound ha.2.1 hb.2.1 hr
  subst ms; subst qs; subst t
  exact Or.inr ⟨ns, ps, r, e, f, rfl, rfl, effSub_sound ha.2.2 hb.2.2 he⟩

def tyJoin (s : List Atom) (a b : Ty) : Option Ty :=
  match a, b with
  | .fn ns ps r e, .fn ms qs t f =>
      if (ns == ms) && tysEq s ps qs && tyEq s r t then
        some (.fn ns ps r (unionEff s e f)) else none
  | _, _ => if tyEq s a b then some a else none

theorem tyJoin_sound {s a b j} (ha : Ty.Support (· ∈ s) a) (hb : Ty.Support (· ∈ s) b)
    (h : tyJoin s a b = some j) : Ty.Le a j ∧ Ty.Le b j := by
  cases a <;> cases b <;> simp only [tyJoin] at h
    <;> split at h <;> simp only [Option.some.injEq, reduceCtorEq] at h
    <;> try (subst j; exact ⟨Or.inl rfl, Or.inl (tyEq_sound ha hb ‹_›).symm⟩)
  rename_i ns ps r e ms qs t f hh
  simp only [Bool.and_eq_true_iff] at hh
  rcases hh with ⟨⟨hn, hp⟩, hr⟩
  have hn := eq_of_beq hn
  have hp := (tysEq_spec ha.1 hb.1).mp hp
  have hr := tyEq_sound ha.2.1 hb.2.1 hr
  subst ms; subst qs; subst t; subst j
  rw [unionEff_eq ha.2.2 hb.2.2]
  constructor
  · exact Or.inr ⟨ns, ps, r, e, Eff.union e f, rfl, rfl,
      ⟨fun a h => (Eff.mem_union _ _ a).mpr (Or.inl h),
        fun t h => (Eff.memFail_union _ _ t).mpr (Or.inl h)⟩⟩
  · exact Or.inr ⟨ns, ps, r, f, Eff.union e f, rfl, rfl,
      ⟨fun a h => (Eff.mem_union _ _ a).mpr (Or.inr h),
        fun t h => (Eff.memFail_union _ _ t).mpr (Or.inr h)⟩⟩

theorem tyJoin_support {s a b j} (ha : Ty.Support (· ∈ s) a) (hb : Ty.Support (· ∈ s) b)
    (h : tyJoin s a b = some j) : Ty.Support (· ∈ s) j := by
  cases a <;> cases b <;> simp only [tyJoin] at h
    <;> split at h <;> simp only [Option.some.injEq, reduceCtorEq] at h
    <;> try (subst j; exact ha)
  subst j
  exact ⟨ha.1, ha.2.1, unionEff_support ha.2.2 hb.2.2⟩

/-- 通常の名前の捕捉ではFail列を保ち、支持外の原子を切り捨てない。 -/
def diffEff (e h : Eff) : Eff := .mk (fun a => Eff.test e a && !Eff.test h a) e.fails

theorem diffEff_support {s : List Atom} {e h : Eff} (he : Eff.Support (· ∈ s) e) :
    Eff.Support (· ∈ s) (diffEff e h) := by
  rw [Eff.support_iff] at he
  exact ⟨fun a ha => he.1 a (Bool.and_eq_true_iff.mp ha).1, he.2⟩

theorem diffEff_cover (e h : Eff) : Eff.Sub e (Eff.union (diffEff e h) h) := by
  constructor
  · intro a he
    apply (Eff.mem_union _ _ a).mpr
    cases hh : Eff.test h a
    · exact Or.inl (by change (Eff.test e a && !(Eff.test h a)) = true; rw [he, hh]; rfl)
    · exact Or.inr hh
  · intro t ht
    exact (Eff.memFail_union _ _ t).mpr (Or.inl ht)

theorem diffEff_mono {e f h : Eff} (hh : Eff.Sub e f) : Eff.Sub (diffEff e h) (diffEff f h) := by
  constructor
  · intro a ha
    have ⟨he, hn⟩ := Bool.and_eq_true_iff.mp ha
    exact Bool.and_eq_true_iff.mpr ⟨hh.1 a he, hn⟩
  · exact hh.2

end Benitoite.Surface.CheckTools.Finite
