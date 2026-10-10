import Benitoite.Surface.Typing
import Benitoite.Release.Coverage

/-! 判定の有限の原子集合と、カーネルで評価できる型の操作。 -/
namespace Benitoite.Release

def Eff.AtomsIn (atoms : List Atom) (ε : Eff) : Prop :=
  ∀ a, ε a = true → a ∈ atoms

mutual
  def Ty.AtomsIn (atoms : List Atom) : Ty → Prop
    | .data _ ts | .tapp _ ts => Tys.AtomsIn atoms ts
    | .list t | .reference t | .lazy t | .set t | .dict _ t => t.AtomsIn atoms
    | .fn ps r ε => Tys.AtomsIn atoms ps ∧ r.AtomsIn atoms ∧ ε.AtomsIn atoms
    | .cont b t ε => b.AtomsIn atoms ∧ t.AtomsIn atoms ∧ ε.AtomsIn atoms
    | .map a b => a.AtomsIn atoms ∧ b.AtomsIn atoms
    | _ => True
  def Tys.AtomsIn (atoms : List Atom) : List Ty → Prop
    | [] => True
    | t :: ts => t.AtomsIn atoms ∧ Tys.AtomsIn atoms ts
end
end Benitoite.Release

namespace Benitoite.Surface.CheckTools
open Benitoite.Release

def effSub (atoms : List Atom) (ε ε' : Eff) : Bool :=
  atoms.all fun a => !ε a || ε' a

def effEq (atoms : List Atom) (ε ε' : Eff) : Bool :=
  atoms.all fun a => ε a == ε' a

def emptyEff : Eff := Eff.empty

def singleEff (atoms : List Atom) (a : Atom) : Eff :=
  fun b => atoms.contains a && (b == a)

def unionEff (atoms : List Atom) (ε ε' : Eff) : Eff :=
  fun a => atoms.contains a && (ε a || ε' a)

theorem effSub_sound {atoms ε ε'} (ha : Eff.AtomsIn atoms ε)
    (h : effSub atoms ε ε' = true) : Eff.Sub ε ε' := by
  intro a he
  have := List.all_eq_true.mp h a (ha a he)
  simpa [he] using this

theorem effEq_sound {atoms ε ε'} (ha : Eff.AtomsIn atoms ε)
    (hb : Eff.AtomsIn atoms ε') (h : effEq atoms ε ε' = true) : ε = ε' := by
  funext a
  by_cases hm : a ∈ atoms
  · exact eq_of_beq (List.all_eq_true.mp h a hm)
  · have h₁ : ε a = false := by cases he : ε a <;> simp_all [Eff.AtomsIn]
    have h₂ : ε' a = false := by cases he : ε' a <;> simp_all [Eff.AtomsIn]
    rw [h₁, h₂]

theorem emptyEff_atoms (atoms : List Atom) : Eff.AtomsIn atoms emptyEff := by
  intro a h; cases h

theorem singleEff_atoms (atoms : List Atom) (a : Atom) :
    Eff.AtomsIn atoms (singleEff atoms a) := by
  intro b h
  have ⟨ha, hb⟩ : atoms.contains a = true ∧ (b == a) = true := by simpa [singleEff] using h
  have : b = a := eq_of_beq hb
  subst b
  exact List.mem_of_elem_eq_true ha

theorem singleEff_eq {atoms : List Atom} {l : EffName} (h : Atom.name l ∈ atoms) :
    singleEff atoms (.name l) = Eff.single l := by
  funext a; simp [singleEff, Eff.single, h]

theorem unionEff_atoms (atoms : List Atom) (ε ε' : Eff) :
    Eff.AtomsIn atoms (unionEff atoms ε ε') := by
  intro a h
  have ⟨hm, _⟩ : atoms.contains a = true ∧ (ε a || ε' a) = true := by simpa [unionEff] using h
  exact List.mem_of_elem_eq_true hm

theorem union_atoms {atoms ε ε'} (ha : Eff.AtomsIn atoms ε) (hb : Eff.AtomsIn atoms ε') :
    Eff.AtomsIn atoms (Eff.union ε ε') := by
  intro a h
  have hh : ε a = true ∨ ε' a = true := by simpa [Eff.union] using h
  rcases hh with h | h
  · exact ha a h
  · exact hb a h

theorem unionEff_eq {atoms ε ε'} (ha : Eff.AtomsIn atoms ε) (hb : Eff.AtomsIn atoms ε') :
    unionEff atoms ε ε' = Eff.union ε ε' := by
  funext a
  by_cases h : a ∈ atoms
  · simp [unionEff, Eff.union, h]
  · have he : Eff.union ε ε' a = false := by
      cases hx : Eff.union ε ε' a
      · rfl
      · exact False.elim (h (union_atoms ha hb a hx))
    simp [unionEff, h, he]

def tyConEq : TyCon → TyCon → Bool
  | .data a, .data b => a == b
  | .list, .list | .set, .set | .map, .map | .reference, .reference | .lazy, .lazy => true
  | _, _ => false

mutual
  def tyEq (atoms : List Atom) : Ty → Ty → Bool
    | .base a, .base b => a == b
    | .opaque a, .opaque b => a == b
    | .data a ts, .data b us => (a == b) && tysEq atoms ts us
    | .list a, .list b | .reference a, .reference b | .lazy a, .lazy b
      | .set a, .set b => tyEq atoms a b
    | .fn ps r ε, .fn qs s ε' => tysEq atoms ps qs && tyEq atoms r s && effEq atoms ε ε'
    | .cont b t ε, .cont b' t' ε' => tyEq atoms b b' && tyEq atoms t t' && effEq atoms ε ε'
    | .map a b, .map a' b' => tyEq atoms a a' && tyEq atoms b b'
    | .tvar i, .tvar j => i == j
    | .bytes, .bytes => true
    | .dict cl t, .dict cl' t' => (cl == cl') && tyEq atoms t t'
    | .tapp i ts, .tapp j us => (i == j) && tysEq atoms ts us
    | .ctor a, .ctor b => tyConEq a b
    | _, _ => false
  def tysEq (atoms : List Atom) : List Ty → List Ty → Bool
    | [], [] => true
    | t :: ts, u :: us => tyEq atoms t u && tysEq atoms ts us
    | _, _ => false
end

theorem tyConEq_sound {a b : TyCon} (h : tyConEq a b = true) : a = b := by
  cases a <;> cases b <;> simp_all [tyConEq]

mutual
  theorem tyEq_soundAux (atoms : List Atom) : (a b : Ty) →
      Ty.AtomsIn atoms a → Ty.AtomsIn atoms b → tyEq atoms a b = true → a = b
    | .base _, b, _, _, h => by cases b <;> simp_all [tyEq]
    | .opaque _, b, _, _, h => by cases b <;> simp_all [tyEq]
    | .tvar _, b, _, _, h => by cases b <;> simp_all [tyEq]
    | .bytes, b, _, _, h => by cases b <;> simp_all [tyEq]
    | .ctor c, b, _, _, h => by
        cases b <;> simp only [tyEq] at h <;> try contradiction
        exact congrArg Ty.ctor (tyConEq_sound h)
    | .list a, b, ha, hb, h => by
        cases b <;> simp only [tyEq] at h <;> try contradiction
        exact congrArg Ty.list (tyEq_soundAux atoms _ _ ha hb h)
    | .reference a, b, ha, hb, h => by
        cases b <;> simp only [tyEq] at h <;> try contradiction
        exact congrArg Ty.reference (tyEq_soundAux atoms _ _ ha hb h)
    | .lazy a, b, ha, hb, h => by
        cases b <;> simp only [tyEq] at h <;> try contradiction
        exact congrArg Ty.lazy (tyEq_soundAux atoms _ _ ha hb h)
    | .set a, b, ha, hb, h => by
        cases b <;> simp only [tyEq] at h <;> try contradiction
        exact congrArg Ty.set (tyEq_soundAux atoms _ _ ha hb h)
    | .data d ts, b, ha, hb, h => by
        cases b <;> simp only [tyEq] at h <;> try contradiction
        have ⟨hd, ht⟩ := Bool.and_eq_true_iff.mp h
        have he := eq_of_beq hd
        have hs := tysEq_soundAux atoms _ _ ha hb ht
        subst_vars; rfl
    | .tapp i ts, b, ha, hb, h => by
        cases b <;> simp only [tyEq] at h <;> try contradiction
        have ⟨hi, ht⟩ := Bool.and_eq_true_iff.mp h
        have he := eq_of_beq hi
        have hs := tysEq_soundAux atoms _ _ ha hb ht
        subst_vars; rfl
    | .dict cl a, b, ha, hb, h => by
        cases b <;> simp only [tyEq] at h <;> try contradiction
        rename_i cl' a'
        have ⟨hc, ht⟩ := Bool.and_eq_true_iff.mp h
        have he := eq_of_beq hc
        have hs := tyEq_soundAux atoms a a' ha hb ht
        subst_vars; rfl
    | .map a b, t, ha, hb, h => by
        cases t <;> simp only [tyEq] at h <;> try contradiction
        have ⟨h₁, h₂⟩ := Bool.and_eq_true_iff.mp h
        have he₁ := tyEq_soundAux atoms _ _ ha.1 hb.1 h₁
        have he₂ := tyEq_soundAux atoms _ _ ha.2 hb.2 h₂
        subst_vars; rfl
    | .fn ps r ε, t, ha, hb, h => by
        cases t <;> simp only [tyEq] at h <;> try contradiction
        rename_i qs s ε'
        have ⟨⟨hp, hr⟩, he⟩ : (tysEq atoms ps qs = true ∧ tyEq atoms r s = true) ∧
            effEq atoms ε ε' = true := by simpa using h
        have he₁ := tysEq_soundAux atoms _ _ ha.1 hb.1 hp
        have he₂ := tyEq_soundAux atoms _ _ ha.2.1 hb.2.1 hr
        have he₃ := effEq_sound ha.2.2 hb.2.2 he
        subst_vars; rfl
    | .cont b t ε, a, ha, hb, h => by
        cases a <;> simp only [tyEq] at h <;> try contradiction
        rename_i b' t' ε'
        have ⟨⟨h₁, h₂⟩, he⟩ : (tyEq atoms b b' = true ∧ tyEq atoms t t' = true) ∧
            effEq atoms ε ε' = true := by simpa using h
        have he₁ := tyEq_soundAux atoms _ _ ha.1 hb.1 h₁
        have he₂ := tyEq_soundAux atoms _ _ ha.2.1 hb.2.1 h₂
        have he₃ := effEq_sound ha.2.2 hb.2.2 he
        subst_vars; rfl
  theorem tysEq_soundAux (atoms : List Atom) : (ts us : List Ty) →
      Tys.AtomsIn atoms ts → Tys.AtomsIn atoms us → tysEq atoms ts us = true → ts = us
    | [], us, _, _, h => by cases us <;> simp_all [tysEq]
    | t :: ts, us, ha, hb, h => by
        cases us with
        | nil => simp [tysEq] at h
        | cons u us =>
            have ⟨ht, hs⟩ := Bool.and_eq_true_iff.mp h
            have he₁ := tyEq_soundAux atoms t u ha.1 hb.1 ht
            have he₂ := tysEq_soundAux atoms ts us ha.2 hb.2 hs
            subst_vars; rfl
end

theorem tyEq_sound {atoms a b} (ha : Ty.AtomsIn atoms a) (hb : Ty.AtomsIn atoms b)
    (h : tyEq atoms a b = true) : a = b := tyEq_soundAux atoms a b ha hb h

theorem tysEq_sound {atoms ts us} (ha : Tys.AtomsIn atoms ts) (hb : Tys.AtomsIn atoms us)
    (h : tysEq atoms ts us = true) : ts = us := tysEq_soundAux atoms ts us ha hb h

def tyLe (atoms : List Atom) (a b : Ty) : Bool :=
  match a, b with
  | .fn ps r ε, .fn qs s ε' => tysEq atoms ps qs && tyEq atoms r s && effSub atoms ε ε'
  | _, _ => tyEq atoms a b

theorem tyLe_sound {atoms a b} (ha : Ty.AtomsIn atoms a) (hb : Ty.AtomsIn atoms b)
    (h : tyLe atoms a b = true) : Ty.Le a b := by
  cases a <;> cases b <;> try exact Or.inl (tyEq_sound ha hb h)
  rename_i ps r ε qs s ε'
  have ⟨⟨hp, hr⟩, he⟩ : (tysEq atoms ps qs = true ∧ tyEq atoms r s = true) ∧
      effSub atoms ε ε' = true := by simpa [tyLe] using h
  have hps := tysEq_sound ha.1 hb.1 hp
  have hrs := tyEq_sound ha.2.1 hb.2.1 hr
  subst qs; subst s
  exact Or.inr ⟨ps, r, ε, ε', rfl, rfl, effSub_sound ha.2.2 he⟩

/-- 適用は再帰を必要としない。型引数を再び辿らず、そのまま挿入する。 -/
def applyToTy (t : Ty) (args : List Ty) : Ty :=
  match t with
  | .ctor φ => φ.apply args
  | .tvar j => .tapp j args
  | t => t

theorem applyToTy_eq (t : Ty) (args : List Ty) : applyToTy t args = t.applyTo args := rfl

mutual
  def shiftTy (k c : Nat) : Ty → Ty
    | .base b => .base b
    | .opaque o => .opaque o
    | .data d args => .data d (shiftTys k c args)
    | .list a => .list (shiftTy k c a)
    | .fn ps r eff => .fn (shiftTys k c ps) (shiftTy k c r) eff
    | .tvar i => if i < c then .tvar i else .tvar (i + k)
    | .reference a => .reference (shiftTy k c a)
    | .lazy a => .lazy (shiftTy k c a)
    | .cont b t eff => .cont (shiftTy k c b) (shiftTy k c t) eff
    | .map a b => .map (shiftTy k c a) (shiftTy k c b)
    | .set a => .set (shiftTy k c a)
    | .bytes => .bytes
    | .dict cl a => .dict cl (shiftTy k c a)
    | .tapp i args => .tapp (if i < c then i else i + k) (shiftTys k c args)
    | .ctor c => .ctor c
  def shiftTys (k c : Nat) : List Ty → List Ty
    | [] => []
    | a :: as => shiftTy k c a :: shiftTys k c as
end

mutual
  theorem shiftTy_eq (k c : Nat) : (a : Ty) → shiftTy k c a = Ty.shift k c a
    | .base b => by simp only [shiftTy, Ty.shift]
    | .opaque o => by simp only [shiftTy, Ty.shift]
    | .data d args => by simp only [shiftTy, Ty.shift, shiftTys_eq]
    | .list a => by simp only [shiftTy, Ty.shift, shiftTy_eq k c a]
    | .fn ps r eff => by simp only [shiftTy, Ty.shift, shiftTys_eq, shiftTy_eq k c r]
    | .tvar i => by simp only [shiftTy, Ty.shift]
    | .reference a => by simp only [shiftTy, Ty.shift, shiftTy_eq k c a]
    | .lazy a => by simp only [shiftTy, Ty.shift, shiftTy_eq k c a]
    | .cont b t eff => by simp only [shiftTy, Ty.shift, shiftTy_eq k c b, shiftTy_eq k c t]
    | .map a b => by simp only [shiftTy, Ty.shift, shiftTy_eq k c a, shiftTy_eq k c b]
    | .set a => by simp only [shiftTy, Ty.shift, shiftTy_eq k c a]
    | .bytes => by simp only [shiftTy, Ty.shift]
    | .dict cl a => by simp only [shiftTy, Ty.shift, shiftTy_eq k c a]
    | .tapp i args => by simp only [shiftTy, Ty.shift, shiftTys_eq]
    | .ctor c => by simp only [shiftTy, Ty.shift]
  theorem shiftTys_eq (k c : Nat) : (as : List Ty) → shiftTys k c as = as.map (Ty.shift k c)
    | [] => rfl
    | a :: as => by simp only [shiftTys, List.map_cons]; rw [shiftTy_eq, shiftTys_eq]
end

mutual
  def substTyAt (c : Nat) (ts : List Ty) (es : List Eff) : Ty → Ty
    | .base b => .base b
    | .opaque o => .opaque o
    | .data d args => .data d (substTysAt c ts es args)
    | .list a => .list (substTyAt c ts es a)
    | .fn ps r eff => .fn (substTysAt c ts es ps) (substTyAt c ts es r) (Eff.substRho es eff)
    | .tvar i => if i < c then .tvar i else if i - c < ts.length then shiftTy c 0 ((ts[i - c]?).getD (.tvar i)) else .tvar (i - ts.length)
    | .reference a => .reference (substTyAt c ts es a)
    | .lazy a => .lazy (substTyAt c ts es a)
    | .cont b t eff => .cont (substTyAt c ts es b) (substTyAt c ts es t) (Eff.substRho es eff)
    | .map k v => .map (substTyAt c ts es k) (substTyAt c ts es v)
    | .set a => .set (substTyAt c ts es a)
    | .bytes => .bytes
    | .dict cl a => .dict cl (substTyAt c ts es a)
    | .tapp i args => if i < c then .tapp i (substTysAt c ts es args) else if i - c < ts.length then applyToTy (shiftTy c 0 ((ts[i - c]?).getD (.tvar i))) (substTysAt c ts es args) else .tapp (i - ts.length) (substTysAt c ts es args)
    | .ctor c => .ctor c
  def substTysAt (c : Nat) (ts : List Ty) (es : List Eff) : List Ty → List Ty
    | [] => []
    | a :: as => substTyAt c ts es a :: substTysAt c ts es as
end

mutual
  theorem substTyAt_eq (c : Nat) (ts : List Ty) (es : List Eff) : (a : Ty) → substTyAt c ts es a = Ty.substAt c ts es a
    | .base b => by simp only [substTyAt, Ty.substAt]
    | .opaque o => by simp only [substTyAt, Ty.substAt]
    | .data d args => by simp only [substTyAt, Ty.substAt, substTysAt_eq]
    | .list a => by simp only [substTyAt, Ty.substAt, substTyAt_eq c ts es a]
    | .fn ps r eff => by simp only [substTyAt, Ty.substAt, substTysAt_eq, substTyAt_eq c ts es r]
    | .tvar i => by simp only [substTyAt, Ty.substAt, shiftTy_eq]
    | .reference a => by simp only [substTyAt, Ty.substAt, substTyAt_eq c ts es a]
    | .lazy a => by simp only [substTyAt, Ty.substAt, substTyAt_eq c ts es a]
    | .cont b t eff => by simp only [substTyAt, Ty.substAt, substTyAt_eq c ts es b, substTyAt_eq c ts es t]
    | .map k v => by simp only [substTyAt, Ty.substAt, substTyAt_eq c ts es k, substTyAt_eq c ts es v]
    | .set a => by simp only [substTyAt, Ty.substAt, substTyAt_eq c ts es a]
    | .bytes => by simp only [substTyAt, Ty.substAt]
    | .dict cl a => by simp only [substTyAt, Ty.substAt, substTyAt_eq c ts es a]
    | .tapp i args => by simp only [substTyAt, Ty.substAt, substTysAt_eq, shiftTy_eq, applyToTy_eq]
    | .ctor c => by simp only [substTyAt, Ty.substAt]
  theorem substTysAt_eq (c : Nat) (ts : List Ty) (es : List Eff) : (as : List Ty) → substTysAt c ts es as = as.map (Ty.substAt c ts es)
    | [] => rfl
    | a :: as => by simp only [substTysAt, List.map_cons]; rw [substTyAt_eq, substTysAt_eq]
end

def substTy (ts : List Ty) (es : List Eff) (a : Ty) : Ty := substTyAt 0 ts es a

theorem substTy_eq (ts : List Ty) (es : List Eff) (a : Ty) :
    substTy ts es a = a.subst ts es := substTyAt_eq 0 ts es a

def fnTyCheck (params : List Ty) (ret : Ty) (eff : Eff) (ts : List Ty) (es : List Eff) : Ty :=
  substTy ts es (.fn params ret eff)

theorem fnTyCheck_eq (params : List Ty) (ret : Ty) (eff : Eff) (ts : List Ty) (es : List Eff) :
    fnTyCheck params ret eff ts es = fnTy params ret eff ts es := substTy_eq ts es _

theorem substRho_atoms {atoms es ε} (ha : Eff.AtomsIn atoms ε)
    (he : ∀ e ∈ es, Eff.AtomsIn atoms e) : Eff.AtomsIn atoms (Eff.substRho es ε) := by
  intro a h
  rcases Bool.or_eq_true_iff.mp h with h | h
  · cases a with
    | name l => exact ha _ h
    | rho i =>
        dsimp at h
        split at h
        · contradiction
        · exact ha _ h
  · obtain ⟨i, _, hi⟩ := List.any_eq_true.mp h
    have hx := (Bool.and_eq_true_iff.mp hi).2
    cases hg : es[i]? with
    | none => simp [hg] at hx
    | some e => exact he e (List.mem_of_getElem? hg) a (by simpa [hg] using hx)

private theorem atoms_getD {atoms ts fallback} {i : Nat} (h : Tys.AtomsIn atoms ts)
    (hf : Ty.AtomsIn atoms fallback) : Ty.AtomsIn atoms ((ts[i]?).getD fallback) := by
  induction ts generalizing i with
  | nil => exact hf
  | cons t ts ih =>
      cases i with
      | zero => exact h.1
      | succ i => exact ih h.2

mutual
  private theorem shiftTy_atomsAux {atoms} (k c : Nat) : (a : Ty) →
      Ty.AtomsIn atoms a → Ty.AtomsIn atoms (shiftTy k c a)
    | .base _, _ | .opaque _, _ | .bytes, _ | .ctor _, _ => trivial
    | .tvar i, _ => by simp only [shiftTy]; split <;> trivial
    | .data _ ts, h | .tapp _ ts, h => shiftTys_atomsAux k c ts h
    | .list a, h | .reference a, h | .lazy a, h | .set a, h | .dict _ a, h =>
        shiftTy_atomsAux k c a h
    | .fn ps r _, h => ⟨shiftTys_atomsAux k c ps h.1, shiftTy_atomsAux k c r h.2.1, h.2.2⟩
    | .cont b t _, h => ⟨shiftTy_atomsAux k c b h.1, shiftTy_atomsAux k c t h.2.1, h.2.2⟩
    | .map a b, h => ⟨shiftTy_atomsAux k c a h.1, shiftTy_atomsAux k c b h.2⟩
  private theorem shiftTys_atomsAux {atoms} (k c : Nat) : (ts : List Ty) →
      Tys.AtomsIn atoms ts → Tys.AtomsIn atoms (shiftTys k c ts)
    | [], _ => trivial
    | t :: ts, h => ⟨shiftTy_atomsAux k c t h.1, shiftTys_atomsAux k c ts h.2⟩
end

theorem shift_atoms {atoms a} (ha : Ty.AtomsIn atoms a) (k c : Nat) :
    Ty.AtomsIn atoms (a.shift k c) := by
  rw [← shiftTy_eq]; exact shiftTy_atomsAux k c a ha

theorem applyTo_atoms {atoms a ts} (ha : Ty.AtomsIn atoms a) (ht : Tys.AtomsIn atoms ts) :
    Ty.AtomsIn atoms (a.applyTo ts) := by
  cases a <;> try exact ha
  · exact ht
  · rename_i φ
    have hh : Ty.AtomsIn atoms (ts.headD (.base .unit)) := by
      cases ts with
      | nil => trivial
      | cons t ts => exact ht.1
    have ht' : Ty.AtomsIn atoms (ts.tail.headD (.base .unit)) := by
      cases ts with
      | nil => trivial
      | cons t ts =>
          cases ts with
          | nil => trivial
          | cons u us => exact ht.2.1
    cases φ <;> simp only [Ty.applyTo, TyCon.apply, Ty.AtomsIn] <;> first | exact ht | exact hh | exact ⟨hh, ht'⟩

mutual
  private theorem substTyAt_atomsAux {atoms ts es} (ht : Tys.AtomsIn atoms ts)
      (he : ∀ e ∈ es, Eff.AtomsIn atoms e) (c : Nat) : (a : Ty) →
      Ty.AtomsIn atoms a → Ty.AtomsIn atoms (substTyAt c ts es a)
    | .base _, _ | .opaque _, _ | .bytes, _ | .ctor _, _ => trivial
    | .data _ as, h => substTysAt_atomsAux ht he c as h
    | .list a, h | .reference a, h | .lazy a, h | .set a, h | .dict _ a, h =>
        substTyAt_atomsAux ht he c a h
    | .fn ps r ε, h => ⟨substTysAt_atomsAux ht he c ps h.1,
        substTyAt_atomsAux ht he c r h.2.1, substRho_atoms h.2.2 he⟩
    | .cont b t ε, h => ⟨substTyAt_atomsAux ht he c b h.1,
        substTyAt_atomsAux ht he c t h.2.1, substRho_atoms h.2.2 he⟩
    | .map a b, h => ⟨substTyAt_atomsAux ht he c a h.1, substTyAt_atomsAux ht he c b h.2⟩
    | .tvar i, _ => by
        simp only [substTyAt]; split
        · trivial
        · split
          · exact shiftTy_atomsAux c 0 _ (atoms_getD ht (by trivial))
          · trivial
    | .tapp i as, h => by
        have hs := substTysAt_atomsAux ht he c as h
        simp only [substTyAt]; split
        · exact hs
        · split
          · exact applyTo_atoms (shiftTy_atomsAux c 0 _ (atoms_getD ht (by trivial))) hs
          · exact hs
  private theorem substTysAt_atomsAux {atoms ts es} (ht : Tys.AtomsIn atoms ts)
      (he : ∀ e ∈ es, Eff.AtomsIn atoms e) (c : Nat) : (as : List Ty) →
      Tys.AtomsIn atoms as → Tys.AtomsIn atoms (substTysAt c ts es as)
    | [], _ => trivial
    | a :: as, h => ⟨substTyAt_atomsAux ht he c a h.1, substTysAt_atomsAux ht he c as h.2⟩
end

theorem substAt_atoms {atoms a ts es} (ha : Ty.AtomsIn atoms a)
    (ht : Tys.AtomsIn atoms ts) (he : ∀ e ∈ es, Eff.AtomsIn atoms e) (c : Nat) :
    Ty.AtomsIn atoms (a.substAt c ts es) := by
  rw [← substTyAt_eq]; exact substTyAt_atomsAux ht he c a ha

theorem subst_atoms {atoms a ts es} (ha : Ty.AtomsIn atoms a)
    (ht : Tys.AtomsIn atoms ts) (he : ∀ e ∈ es, Eff.AtomsIn atoms e) :
    Ty.AtomsIn atoms (a.subst ts es) := substAt_atoms ha ht he 0

theorem shiftTy_atoms {atoms a} (ha : Ty.AtomsIn atoms a) (k c : Nat) :
    Ty.AtomsIn atoms (shiftTy k c a) := by rw [shiftTy_eq]; exact shift_atoms ha k c

theorem applyToTy_atoms {atoms a ts} (ha : Ty.AtomsIn atoms a) (ht : Tys.AtomsIn atoms ts) :
    Ty.AtomsIn atoms (applyToTy a ts) := applyTo_atoms ha ht

theorem substTyAt_atoms {atoms a ts es} (ha : Ty.AtomsIn atoms a)
    (ht : Tys.AtomsIn atoms ts) (he : ∀ e ∈ es, Eff.AtomsIn atoms e) (c : Nat) :
    Ty.AtomsIn atoms (substTyAt c ts es a) := by
  rw [substTyAt_eq]; exact substAt_atoms ha ht he c

theorem substTy_atoms {atoms a ts es} (ha : Ty.AtomsIn atoms a)
    (ht : Tys.AtomsIn atoms ts) (he : ∀ e ∈ es, Eff.AtomsIn atoms e) :
    Ty.AtomsIn atoms (substTy ts es a) := substTyAt_atoms ha ht he 0

theorem fnTyCheck_atoms {atoms params ret eff ts es}
    (hp : Tys.AtomsIn atoms params) (hr : Ty.AtomsIn atoms ret) (he : Eff.AtomsIn atoms eff)
    (ht : Tys.AtomsIn atoms ts) (hes : ∀ e ∈ es, Eff.AtomsIn atoms e) :
    Ty.AtomsIn atoms (fnTyCheck params ret eff ts es) := substTy_atoms ⟨hp, hr, he⟩ ht hes

theorem shiftTys_atoms {atoms ts} (ht : Tys.AtomsIn atoms ts) (k c : Nat) :
    Tys.AtomsIn atoms (shiftTys k c ts) := by
  induction ts with
  | nil => trivial
  | cons t ts ih => exact ⟨shiftTy_atoms ht.1 k c, ih ht.2⟩

theorem substTysAt_atoms {atoms as ts es} (ha : Tys.AtomsIn atoms as)
    (ht : Tys.AtomsIn atoms ts) (he : ∀ e ∈ es, Eff.AtomsIn atoms e) (c : Nat) :
    Tys.AtomsIn atoms (substTysAt c ts es as) := by
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
  | nil => simp [Tys.AtomsIn]
  | cons t ts ih => simp [Tys.AtomsIn, ih]

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
