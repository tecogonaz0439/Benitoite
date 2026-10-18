import Std
import Benitoite.Release.Atom

/-!
# 名前と行の関数の固定順序

任意の支持を持つ関数を、原子の符号が最小の相違点で比較する。
有限支持に制限せず、等号は関数の外延性と一致する。
型表現の移行前に順序の法則を確かめる（設計書 07-04「01-12 との対応」）。
-/

namespace Benitoite.Release

namespace Atom

/-- Unicode スカラー値に1を足した桁の基数。0は列の終端だけに使う。 -/
def codeBase : Nat := 1114113

/-- 文字列の符号。文字列自体の辞書式比較とは区別する。 -/
def charsCode : List Char → Nat
  | [] => 0
  | c :: cs => c.toNat + 1 + codeBase * charsCode cs

private theorem digit_lt (c : Char) : c.toNat + 1 < codeBase := by
  have h := c.valid
  simp only [UInt32.isValidChar, Nat.isValidChar] at h
  change c.val.toNat + 1 < 1114113
  omega

private theorem charsCode_injective {cs ds : List Char} (h : charsCode cs = charsCode ds) : cs = ds := by
  induction cs generalizing ds with
  | nil => cases ds <;> simp_all [charsCode] <;> omega
  | cons c cs ih =>
    cases ds with
    | nil => simp [charsCode] at h
    | cons d ds =>
      have hc := digit_lt c
      have hd := digit_lt d
      have hr := congrArg (· % codeBase) h
      simp only [charsCode, Nat.add_mod, Nat.mul_mod_right, Nat.add_zero,
        Nat.mod_eq_of_lt hc, Nat.mod_eq_of_lt hd] at hr
      have he : c = d := Char.toNat_inj.mp (by omega)
      subst d
      have ht : charsCode cs = charsCode ds := by
        simp only [charsCode, codeBase] at h
        omega
      exact congrArg (c :: ·) (ih ht)

/-- 名前は偶数、行変数は奇数へ写す。 -/
def code : Atom → Nat
  | .name s => 2 * charsCode s.toList
  | .rho i => 2 * i + 1

/-- 符号の一致から原子の一致を導く。 -/
theorem code_injective {a b : Atom} (h : code a = code b) : a = b := by
  cases a with
  | name s =>
    cases b with
    | name t =>
      have hc : charsCode s.toList = charsCode t.toList := by simp only [code] at h; omega
      exact congrArg Atom.name (String.toList_inj.mp (charsCode_injective hc))
    | rho i => simp only [code] at h; omega
  | rho i =>
    cases b with
    | name s => simp only [code] at h; omega
    | rho j => have : i = j := by simp only [code] at h; omega
               exact congrArg Atom.rho this

end Atom

private theorem exists_least_atom (p : Atom → Prop) (h : ∃ a, p a) :
    ∃ a, p a ∧ ∀ b, p b → Atom.code a ≤ Atom.code b := by
  classical
  have aux : ∀ n, ∀ a, Atom.code a = n → p a →
      ∃ a, p a ∧ ∀ b, p b → Atom.code a ≤ Atom.code b := by
    intro n
    induction n using Nat.strongRecOn with
    | ind n ih =>
      intro a ha hp
      by_cases hs : ∃ b, p b ∧ Atom.code b < n
      · obtain ⟨b, hb, hn⟩ := hs
        exact ih (Atom.code b) hn b rfl hb
      · exact ⟨a, hp, fun b hb => by
          have : ¬ Atom.code b < n := fun hn => hs ⟨b, hb, hn⟩
          omega⟩
  obtain ⟨a, ha⟩ := h
  exact aux (Atom.code a) a rfl ha

private theorem exists_atoms_difference {f g : Atom → Bool} (h : f ≠ g) :
    ∃ a, f a ≠ g a := by
  classical
  by_cases hd : ∃ a, f a ≠ g a
  · exact hd
  · exact False.elim (h (funext (fun a => by
      by_cases he : f a = g a
      · exact he
      · exact False.elim (hd ⟨a, he⟩))))

/-- 最小符号の相違点で false を先にする。選択を使う定義はこの比較だけである。 -/
noncomputable def atomsCompare (f g : Atom → Bool) : Ordering := by
  classical
  exact if h : f = g then .eq else
    let a := Classical.choose (exists_least_atom (fun a => f a ≠ g a) (exists_atoms_difference h))
    compare (f a) (g a)

/-- 狭義比較の証拠。選ばれた点より小さい符号では二関数は一致する。 -/
def AtomsBefore (f g : Atom → Bool) (a : Atom) : Prop :=
  f a = false ∧ g a = true ∧ ∀ b, Atom.code b < Atom.code a → f b = g b

private theorem atomsCompare_spec (f g : Atom → Bool) :
    (atomsCompare f g = .eq ∧ f = g) ∨
    ∃ a, f a ≠ g a ∧ (∀ b, Atom.code b < Atom.code a → f b = g b) ∧
      atomsCompare f g = compare (f a) (g a) := by
  classical
  unfold atomsCompare
  split
  · exact Or.inl ⟨rfl, ‹f = g›⟩
  · rename_i h
    have hs := Classical.choose_spec
      (exists_least_atom (fun a => f a ≠ g a) (exists_atoms_difference h))
    refine Or.inr ⟨_, hs.1, ?_, rfl⟩
    intro b hb
    by_cases he : f b = g b
    · exact he
    · have := hs.2 b he; omega

/-- 数学上の比較の eq は、生の関数の等号と同値である。 -/
theorem atomsCompare_eq_iff {f g : Atom → Bool} : atomsCompare f g = .eq ↔ f = g := by
  constructor
  · intro h
    rcases atomsCompare_spec f g with ⟨_, he⟩ | ⟨a, hn, _, hc⟩
    · exact he
    · rw [h] at hc
      exact False.elim (hn (Std.LawfulEqOrd.eq_of_compare hc.symm))
  · intro h
    subst g
    simp [atomsCompare]

/-- 同じ向きの最初の相違点は一意である。 -/
theorem atomsBefore_unique {f g : Atom → Bool} {a b : Atom}
    (ha : AtomsBefore f g a) (hb : AtomsBefore f g b) : a = b := by
  apply Atom.code_injective
  have h1 : ¬ Atom.code a < Atom.code b := by
    intro h
    have := hb.2.2 a h
    simp [ha.1, ha.2.1] at this
  have h2 : ¬ Atom.code b < Atom.code a := by
    intro h
    have := ha.2.2 b h
    simp [hb.1, hb.2.1] at this
  omega

/-- lt は、最初の相違点で false/true となることと同値である。 -/
theorem atomsCompare_lt_iff {f g : Atom → Bool} :
    atomsCompare f g = .lt ↔ ∃ a, AtomsBefore f g a := by
  constructor
  · intro h
    rcases atomsCompare_spec f g with ⟨he, _⟩ | ⟨a, hn, hm, hc⟩
    · rw [h] at he; contradiction
    · refine ⟨a, ?_, ?_, hm⟩ <;> cases hf : f a <;> cases hg : g a <;> simp_all
  · rintro ⟨a, ha⟩
    rcases atomsCompare_spec f g with ⟨_, he⟩ | ⟨b, hn, hm, hc⟩
    · have := congrFun he a; simp [ha.1, ha.2.1] at this
    · have hab : a = b := by
        apply Atom.code_injective
        have h1 : ¬ Atom.code a < Atom.code b := by
          intro h; have := hm a h; simp [ha.1, ha.2.1] at this
        have h2 : ¬ Atom.code b < Atom.code a := fun h => hn (ha.2.2 b h)
        omega
      subst b
      rw [hc, ha.1, ha.2.1]; rfl

/-- gt は、引数を入れ替えた lt と同値である。 -/
theorem atomsCompare_gt_iff {f g : Atom → Bool} :
    atomsCompare f g = .gt ↔ atomsCompare g f = .lt := by
  have aux : ∀ f g, atomsCompare f g = .gt → atomsCompare g f = .lt := by
    intro f g h
    rcases atomsCompare_spec f g with ⟨he, _⟩ | ⟨a, hn, hm, hc⟩
    · rw [h] at he; contradiction
    · apply atomsCompare_lt_iff.mpr
      refine ⟨a, ?_, ?_, fun b hb => (hm b hb).symm⟩ <;>
        cases hf : f a <;> cases hg : g a <;> simp_all
  constructor
  · exact aux f g
  · intro h
    cases hc : atomsCompare f g with
    | gt => rfl
    | eq => have := atomsCompare_eq_iff.mp hc; subst g; simp [atomsCompare] at h
    | lt =>
      obtain ⟨a, ha⟩ := atomsCompare_lt_iff.mp hc
      obtain ⟨b, hb⟩ := atomsCompare_lt_iff.mp h
      have h1 : ¬ Atom.code a < Atom.code b := by
        intro hab; have := hb.2.2 a hab; simp [ha.1, ha.2.1] at this
      have h2 : ¬ Atom.code b < Atom.code a := by
        intro hba; have := ha.2.2 b hba; simp [hb.1, hb.2.1] at this
      have he := Atom.code_injective (show Atom.code a = Atom.code b by omega)
      subst b
      have := hb.2.1
      simp [ha.1] at this

/-- 引数の交換で比較の向きが反転する。 -/
theorem atomsCompare_swap (f g : Atom → Bool) :
    atomsCompare f g = (atomsCompare g f).swap := by
  cases h : atomsCompare f g with
  | lt => rw [atomsCompare_gt_iff.mpr h]; rfl
  | eq => have := atomsCompare_eq_iff.mp h; subst g; simp [atomsCompare]
  | gt => rw [atomsCompare_gt_iff.mp h]; rfl

/-- 狭義比較の推移性。相違点の符号の小さい方が合成した比較の相違点になる。 -/
theorem atomsCompare_lt_trans {f g h : Atom → Bool}
    (hfg : atomsCompare f g = .lt) (hgh : atomsCompare g h = .lt) : atomsCompare f h = .lt := by
  obtain ⟨a, ha⟩ := atomsCompare_lt_iff.mp hfg
  obtain ⟨b, hb⟩ := atomsCompare_lt_iff.mp hgh
  apply atomsCompare_lt_iff.mpr
  by_cases hab : Atom.code a < Atom.code b
  · refine ⟨a, ha.1, ?_, fun c hc => (ha.2.2 c hc).trans (hb.2.2 c (by omega))⟩
    rw [← hb.2.2 a hab]; exact ha.2.1
  · by_cases hba : Atom.code b < Atom.code a
    · refine ⟨b, ?_, hb.2.1, fun c hc => (ha.2.2 c (by omega)).trans (hb.2.2 c hc)⟩
      rw [ha.2.2 b hba]; exact hb.1
    · have he := Atom.code_injective (show Atom.code a = Atom.code b by omega)
      subst b
      have := hb.1
      simp [ha.2.1] at this

instance : Std.LawfulEqCmp atomsCompare where
  compare_self := atomsCompare_eq_iff.mpr rfl
  eq_of_compare := atomsCompare_eq_iff.mp

instance : Std.TransCmp atomsCompare where
  eq_swap := atomsCompare_swap _ _
  isLE_trans {a b c} hab hbc := by
    cases h1 : atomsCompare a b <;> cases h2 : atomsCompare b c <;> simp_all
    · exact (atomsCompare_lt_trans h1 h2) ▸ rfl
    · subst c; rw [atomsCompare_eq_iff.mpr rfl]; rfl

/-- 任意の二関数は、lt、等号、逆向きのltのいずれかである。 -/
theorem atomsCompare_total (f g : Atom → Bool) :
    atomsCompare f g = .lt ∨ f = g ∨ atomsCompare g f = .lt := by
  cases h : atomsCompare f g with
  | lt => exact Or.inl rfl
  | eq => exact Or.inr (Or.inl (atomsCompare_eq_iff.mp h))
  | gt => exact Or.inr (Or.inr (atomsCompare_gt_iff.mp h))

/-- 両向きの非狭義比較から関数の等号を導く。 -/
theorem atomsCompare_antisymm {f g : Atom → Bool}
    (hfg : (atomsCompare f g).isLE) (hgf : (atomsCompare g f).isLE) : f = g :=
  atomsCompare_eq_iff.mp (Std.OrientedCmp.isLE_antisymm hfg hgf)

/-- 点ごとの所属の一致は比較の eq を与える。 -/
theorem atomsCompare_ext {f g : Atom → Bool} (h : ∀ a, f a = g a) :
    atomsCompare f g = .eq := atomsCompare_eq_iff.mpr (funext h)

end Benitoite.Release
