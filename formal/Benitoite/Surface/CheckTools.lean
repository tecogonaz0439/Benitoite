import Benitoite.Surface.FiniteTools
import Benitoite.Release.FiniteSupport
import Benitoite.Release.Coverage

/-! 検査器の再帰的な有限支持と、計算できる正規化・型操作。 -/
namespace Benitoite.Release
abbrev Eff.AtomsIn (atoms : List Atom) (e : Eff) := Eff.Support (· ∈ atoms) e
abbrev EffR.AtomsIn := Eff.AtomsIn
abbrev Ty.AtomsIn (atoms : List Atom) (t : Ty) := Ty.Support (· ∈ atoms) t
abbrev Tys.AtomsIn (atoms : List Atom) (ts : List Ty) := Ty.SupportList (· ∈ atoms) ts
end Benitoite.Release

namespace Benitoite.Surface.CheckTools
open Benitoite.Release

def effSub := Finite.effSub
def effEq := Finite.effEq
def tyEq := Finite.tyEq
def tysEq := Finite.tysEq
def emptyEff : Eff := Eff.empty
def singleEff (_atoms : List Atom) (a : Atom) : Eff := Eff.ofAtoms (· == a)
def unionEff := Finite.unionEff

theorem effSub_sound {atoms a b} (ha : Eff.AtomsIn atoms a) (hb : Eff.AtomsIn atoms b)
    (h : effSub atoms a b = true) : Eff.Sub a b := Finite.effSub_sound ha hb h

theorem effEq_sound {atoms a b} (ha : Eff.AtomsIn atoms a) (hb : Eff.AtomsIn atoms b)
    (h : effEq atoms a b = true) : a = b := Finite.effEq_sound ha hb h

theorem tyEq_sound {atoms a b} (ha : Ty.AtomsIn atoms a) (hb : Ty.AtomsIn atoms b)
    (h : tyEq atoms a b = true) : a = b := Finite.tyEq_sound ha hb h

theorem tysEq_sound {atoms a b} (ha : Tys.AtomsIn atoms a) (hb : Tys.AtomsIn atoms b)
    (h : tysEq atoms a b = true) : a = b := (Finite.tysEq_spec ha hb).mp h

theorem emptyEff_atoms (atoms : List Atom) : Eff.AtomsIn atoms emptyEff := by
  constructor
  · intro a h; cases h
  · trivial

theorem singleEff_atoms (atoms : List Atom) (a : Atom) (ha : a ∈ atoms) :
    Eff.AtomsIn atoms (singleEff atoms a) := by
  exact ⟨fun b h => (eq_of_beq h) ▸ ha, trivial⟩

theorem singleEff_eq {atoms : List Atom} {l : EffName} (_h : Atom.name l ∈ atoms) :
    singleEff atoms (.name l) = Eff.single l := rfl

theorem union_atoms {atoms a b} (ha : Eff.AtomsIn atoms a) (hb : Eff.AtomsIn atoms b) :
    Eff.AtomsIn atoms (Eff.union a b) := Eff.norm_support _ (Finite.union_support ha hb)

theorem unionEff_atoms {atoms a b} (ha : Eff.AtomsIn atoms a) (hb : Eff.AtomsIn atoms b) :
    Eff.AtomsIn atoms (unionEff atoms a b) := Finite.unionEff_support ha hb

theorem unionEff_eq {atoms a b} (ha : Eff.AtomsIn atoms a) (hb : Eff.AtomsIn atoms b) :
    unionEff atoms a b = Eff.union a b := Finite.unionEff_eq ha hb

def tyLe := Finite.tyLe

theorem tyLe_sound {atoms a b} (ha : Ty.AtomsIn atoms a) (hb : Ty.AtomsIn atoms b)
    (h : tyLe atoms a b = true) : Ty.Le a b := Finite.tyLe_sound ha hb h

def applyToTy := Finite.applyToTy
def shiftTy := Finite.shiftTy
def shiftTys (atoms : List Atom) (k c : Nat) (ts : List Ty) := ts.map (shiftTy atoms k c)
def substTyAt := Finite.substTyAt
def substEffAt := Finite.substEffAt
def shiftEff := Finite.shiftEff
def substTysAt (atoms : List Atom) (c : Nat) (ts : List Ty) (es : List Eff) (as : List Ty) :=
  as.map (substTyAt atoms c ts es)
def substTy (atoms : List Atom) (ts : List Ty) (es : List Eff) (a : Ty) := substTyAt atoms 0 ts es a
def fnTyCheck (atoms : List Atom) (names : List String) (params : List Ty) (ret : Ty) (eff : Eff)
    (ts : List Ty) (es : List Eff) := substTy atoms ts es (.fn names params ret eff)

theorem applyToTy_eq {atoms} (t : Ty) (args : List Ty) (h : t.AtomsIn atoms)
    (hs : Tys.AtomsIn atoms args) : applyToTy atoms t args = t.applyTo args := Finite.applyToTy_eq h hs

theorem shiftTy_eq {atoms} (k c : Nat) (a : Ty) (ha : a.AtomsIn atoms) :
    shiftTy atoms k c a = a.shift k c := Finite.shiftTy_eq ha

theorem shiftTys_eq {atoms} (k c : Nat) (as : List Ty) (ha : Tys.AtomsIn atoms as) :
    shiftTys atoms k c as = Ty.shiftTys k c as := by
  rw [Ty.shiftTys_eq_map]
  exact List.map_congr_left (fun t h => shiftTy_eq k c t (Ty.SupportList.iff.mp ha t h))

theorem shiftEff_eq {atoms} (k c : Nat) (e : Eff) (h : e.AtomsIn atoms) :
    shiftEff atoms k c e = Eff.shift k c e := Finite.shiftEff_eq h

theorem substEffAt_eq {atoms} (c : Nat) (ts : List Ty) (es : List Eff) (e : Eff)
    (ht : ∀ t ∈ ts, t.AtomsIn atoms) (he : ∀ f ∈ es, f.AtomsIn atoms) (h : e.AtomsIn atoms) :
    substEffAt atoms c ts es e = Eff.substAt c ts es e := Finite.substEffAt_eq ht he h

theorem substTyAt_eq {atoms} (c : Nat) (ts : List Ty) (es : List Eff) (a : Ty)
    (ht : ∀ t ∈ ts, t.AtomsIn atoms) (he : ∀ e ∈ es, e.AtomsIn atoms) (ha : a.AtomsIn atoms) :
    substTyAt atoms c ts es a = a.substAt c ts es := Finite.substTyAt_eq ht he ha

theorem substTysAt_eq {atoms} (c : Nat) (ts : List Ty) (es : List Eff) (as : List Ty)
    (ht : ∀ t ∈ ts, t.AtomsIn atoms) (he : ∀ e ∈ es, e.AtomsIn atoms) (ha : ∀ a ∈ as, a.AtomsIn atoms) :
    substTysAt atoms c ts es as = as.map (Ty.substAt c ts es) :=
  List.map_congr_left (fun a h => substTyAt_eq c ts es a ht he (ha a h))

theorem substTy_eq {atoms} (ts : List Ty) (es : List Eff) (a : Ty)
    (ht : ∀ t ∈ ts, t.AtomsIn atoms) (he : ∀ e ∈ es, e.AtomsIn atoms) (ha : a.AtomsIn atoms) :
    substTy atoms ts es a = a.subst ts es := substTyAt_eq 0 ts es a ht he ha

theorem fnTyCheck_eq {atoms} (names : List String) (params : List Ty) (ret : Ty) (eff : Eff)
    (ts : List Ty) (es : List Eff) (ht : ∀ t ∈ ts, t.AtomsIn atoms) (he : ∀ e ∈ es, e.AtomsIn atoms)
    (hp : Tys.AtomsIn atoms params) (hr : ret.AtomsIn atoms) (hf : eff.AtomsIn atoms) :
    fnTyCheck atoms names params ret eff ts es = fnTy names params ret eff ts es :=
  substTy_eq ts es _ ht he ⟨hp, hr, hf⟩

theorem shift_atoms {atoms a} (ha : Ty.AtomsIn atoms a) (k c : Nat) :
    Ty.AtomsIn atoms (a.shift k c) := Ty.shift_support k c a ha

theorem shiftTy_atoms {atoms a} (ha : Ty.AtomsIn atoms a) (k c : Nat) :
    Ty.AtomsIn atoms (shiftTy atoms k c a) := by
  rw [shiftTy_eq k c a ha]; exact shift_atoms ha k c

theorem applyTo_atoms {atoms a ts} (ha : Ty.AtomsIn atoms a) (ht : Tys.AtomsIn atoms ts) :
    Ty.AtomsIn atoms (a.applyTo ts) := by
  rw [Ty.applyTo_eq_raw_norm]
  exact Ty.norm_support _ (Ty.rawApplyTo_support a ts ha ht)

theorem applyToTy_atoms {atoms a ts} (ha : Ty.AtomsIn atoms a) (ht : Tys.AtomsIn atoms ts) :
    Ty.AtomsIn atoms (applyToTy atoms a ts) := by
  rw [applyToTy_eq a ts ha ht]; exact applyTo_atoms ha ht

theorem substAt_atoms {atoms a ts es} (ha : Ty.AtomsIn atoms a)
    (ht : Tys.AtomsIn atoms ts) (he : ∀ e ∈ es, e.AtomsIn atoms) (c : Nat) :
    Ty.AtomsIn atoms (a.substAt c ts es) := Ty.substAt_support c ts es (Ty.SupportList.iff.mp ht) he a ha

theorem substTyAt_atoms {atoms a ts es} (ha : Ty.AtomsIn atoms a)
    (ht : Tys.AtomsIn atoms ts) (he : ∀ e ∈ es, e.AtomsIn atoms) (c : Nat) :
    Ty.AtomsIn atoms (substTyAt atoms c ts es a) := by
  rw [substTyAt_eq c ts es a (Ty.SupportList.iff.mp ht) he ha]; exact substAt_atoms ha ht he c

theorem subst_atoms {atoms a ts es} (ha : Ty.AtomsIn atoms a)
    (ht : Tys.AtomsIn atoms ts) (he : ∀ e ∈ es, e.AtomsIn atoms) :
    Ty.AtomsIn atoms (a.subst ts es) := substAt_atoms ha ht he 0

theorem substEffAt_atoms {atoms ts es e} (ha : e.AtomsIn atoms)
    (ht : Tys.AtomsIn atoms ts) (he : ∀ e ∈ es, e.AtomsIn atoms) (c : Nat) :
    Eff.AtomsIn atoms (substEffAt atoms c ts es e) := by
  rw [substEffAt_eq c ts es e (Ty.SupportList.iff.mp ht) he ha]
  exact Eff.substAt_support c ts es (Ty.SupportList.iff.mp ht) he e ha

theorem substRho_atoms {atoms es e} (ha : Eff.AtomsIn atoms e)
    (he : ∀ e ∈ es, e.AtomsIn atoms) : Eff.AtomsIn atoms (Eff.substRho es e) :=
  Eff.substAt_support 0 [] es (by simp) he e ha

theorem substTy_atoms {atoms a ts es} (ha : Ty.AtomsIn atoms a)
    (ht : Tys.AtomsIn atoms ts) (he : ∀ e ∈ es, e.AtomsIn atoms) :
    Ty.AtomsIn atoms (substTy atoms ts es a) := substTyAt_atoms ha ht he 0

theorem fnTyCheck_atoms {atoms names params ret eff ts es}
    (hp : Tys.AtomsIn atoms params) (hr : Ty.AtomsIn atoms ret) (he : Eff.AtomsIn atoms eff)
    (ht : Tys.AtomsIn atoms ts) (hes : ∀ e ∈ es, e.AtomsIn atoms) :
    Ty.AtomsIn atoms (fnTyCheck atoms names params ret eff ts es) := substTy_atoms ⟨hp, hr, he⟩ ht hes

theorem shiftTys_atoms {atoms ts} (ht : Tys.AtomsIn atoms ts) (k c : Nat) :
    Tys.AtomsIn atoms (shiftTys atoms k c ts) := by
  apply Ty.SupportList.iff.mpr
  intro t h
  obtain ⟨u, hu, rfl⟩ := List.mem_map.mp h
  exact shiftTy_atoms (Ty.SupportList.iff.mp ht u hu) k c

theorem substTysAt_atoms {atoms as ts es} (ha : Tys.AtomsIn atoms as)
    (ht : Tys.AtomsIn atoms ts) (he : ∀ e ∈ es, e.AtomsIn atoms) (c : Nat) :
    Tys.AtomsIn atoms (substTysAt atoms c ts es as) := by
  induction as with
  | nil => trivial
  | cons a as ih => exact ⟨substTyAt_atoms ha.1 ht he c, ih ha.2⟩

abbrev SatDec := List TParam → Ty → TParam → Bool
abbrev AdmitsDec := PrimName → List TParam → List Ty → Bool

/-- 表の構成方法によらない、後続の検査が受け取る判定と表との契約。 -/
def SatDecSound (B : Builtins) (satDec : SatDec) : Prop :=
  ∀ C t p, satDec C t p = true → B.sat C t p

def AdmitsDecSound (B : Builtins) (admitsDec : AdmitsDec) : Prop :=
  ∀ b C ts s, B.sig b = some s → admitsDec b C ts = true → s.admits C ts

def satAll (satDec : SatDec) (C : List TParam) : List Ty → List TParam → Bool
  | [], [] => true
  | t :: ts, p :: ps => satDec C t p && satAll satDec C ts ps
  | _, _ => false

theorem satAll_sound {B satDec C ts ps} (hs : SatDecSound B satDec)
    (h : satAll satDec C ts ps = true) : SatAll B C ts ps := by
  induction ts generalizing ps with
  | nil => cases ps <;> simp_all [satAll, SatAll]
  | cons t ts ih =>
      cases ps with
      | nil => simp [satAll] at h
      | cons p ps =>
          have ⟨ht, hts⟩ : satDec C t p = true ∧ satAll satDec C ts ps = true := by
            simpa [satAll] using h
          obtain ⟨hlen, hrest⟩ := ih hts
          refine ⟨by simp [hlen], ?_⟩
          intro i u q hu hq
          cases i with
          | zero => simp only [List.getElem?_cons_zero, Option.some.injEq] at hu hq
                    subst u; subst q; exact hs C t p ht
          | succ i => exact hrest i u q hu hq

theorem tysAtoms_iff {atoms ts} :
    Tys.AtomsIn atoms ts ↔ ∀ t ∈ ts, Ty.AtomsIn atoms t := by
  induction ts with
  | nil => simp [Ty.SupportList]
  | cons t ts ih => simp [Ty.SupportList, ih]

theorem tysAtoms_getD {atoms ts fallback} {i : Nat} (h : Tys.AtomsIn atoms ts)
    (hf : Ty.AtomsIn atoms fallback) : Ty.AtomsIn atoms ((ts[i]?).getD fallback) := by
  cases he : ts[i]? with
  | none => simpa [he] using hf
  | some t => simpa [he] using tysAtoms_iff.mp h t (List.mem_of_getElem? he)

theorem tysAtoms_take {atoms ts} (h : Tys.AtomsIn atoms ts) (n : Nat) :
    Tys.AtomsIn atoms (ts.take n) :=
  tysAtoms_iff.mpr (fun t ht => tysAtoms_iff.mp h t (List.mem_of_mem_take ht))

theorem tysAtoms_drop {atoms ts} (h : Tys.AtomsIn atoms ts) (n : Nat) :
    Tys.AtomsIn atoms (ts.drop n) :=
  tysAtoms_iff.mpr (fun t ht => tysAtoms_iff.mp h t (List.mem_of_mem_drop ht))

theorem tysAtoms_append {atoms ts us} (ht : Tys.AtomsIn atoms ts) (hu : Tys.AtomsIn atoms us) :
    Tys.AtomsIn atoms (ts ++ us) := by
  rw [tysAtoms_iff]; intro t h
  rcases List.mem_append.mp h with h | h
  · exact tysAtoms_iff.mp ht t h
  · exact tysAtoms_iff.mp hu t h

theorem tysAtoms_map {atoms ts} {f : Ty → Ty} (h : Tys.AtomsIn atoms ts)
    (hf : ∀ t, Ty.AtomsIn atoms t → Ty.AtomsIn atoms (f t)) :
    Tys.AtomsIn atoms (ts.map f) := by
  rw [tysAtoms_iff]; intro t ht
  obtain ⟨u, hu, rfl⟩ := List.mem_map.mp ht
  exact hf u (tysAtoms_iff.mp h u hu)

theorem tysAtoms_map_mem {α : Type} {atoms} {xs : List α} {f : α → Ty}
    (h : ∀ x ∈ xs, Ty.AtomsIn atoms (f x)) : Tys.AtomsIn atoms (xs.map f) := by
  rw [tysAtoms_iff]; intro t ht
  obtain ⟨x, hx, rfl⟩ := List.mem_map.mp ht
  exact h x hx

theorem tysAtoms_replicate {atoms t} (h : Ty.AtomsIn atoms t) (n : Nat) :
    Tys.AtomsIn atoms (List.replicate n t) := by
  rw [tysAtoms_iff]; intro u hu
  have := List.eq_of_mem_replicate hu
  subst u; exact h

theorem tysAtoms_selectSlots {atoms ts slots us} (h : Tys.AtomsIn atoms ts)
    (hs : selectSlots ts slots = some us) : Tys.AtomsIn atoms us :=
  tysAtoms_iff.mpr (fun t ht => tysAtoms_iff.mp h t (selectSlots_mem hs t ht))


end Benitoite.Surface.CheckTools
