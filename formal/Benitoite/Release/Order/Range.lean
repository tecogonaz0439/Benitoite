import Std
import Benitoite.Scope.Signature

/-!
# 範囲と範囲の位置の符号と固定順序

閉じた範囲 `Scope.Domain.Range` と範囲の位置 `Scope.Signature.Ix` に、単射な自然数の符号と、符号の大小に
よる全順序の比較を定める。効果の行の整列と重複除去に使う（判断 5。構造の等号と並びの一致）。範囲の意味
（所属・被覆）の順序ではなく、構造の等号を区別するための固定の順序である。

形は既存の原子の固定順序（`Release.Order.Atoms` の `Atom.code`・`atomsCompare`）に合わせた。名前と範囲の位置を
持つ原子の符号は、名前の符号 `stringCode` と `ixCode` を対の符号 `natPair` で一つにすれば単射のまま
作れる（`nameIxCode_injective`）。本ファイルは `Release.Order.Atoms` を import しないので、原子の順序の
ファイルから本ファイルを import できる（循環しない）。不透明型の木（`Release.Order.Types` の `Ty.toTree`）へは
`ixCode` を番号のラベルとして置ける。比較は `compareOn` と同じく符号の比較であり、`Std.LawfulEqCmp` と
`Std.TransCmp` の実例を持つ。

名前の扱い: `Range` は `Checked.Range` と短い名前が重なるので、本ファイルは `Scope.Domain` を `open` せず、
修飾して書く（`Domain.lean` の先頭のコメント）。
-/

namespace Benitoite.Release.Order

open Std
open Benitoite.Scope

/-! ## 自然数の対の符号 -/

/-- Cantor の対の符号。 -/
def natPair (a b : Nat) : Nat := (a + b) * (a + b + 1) / 2 + a

private def tri : Nat → Nat
  | 0 => 0
  | n + 1 => tri n + n + 1

private theorem tri_lt {n m : Nat} (h : n < m) : tri n + n < tri m := by
  induction m with
  | zero => omega
  | succ m ih =>
    simp only [tri]
    by_cases hm : n = m
    · subst hm; omega
    · have := ih (by omega); omega

private theorem tri_eq_div (n : Nat) : tri n = n * (n + 1) / 2 := by
  induction n with
  | zero => rfl
  | succ n ih =>
    simp only [tri, ih]
    have : (n + 1) * (n + 1 + 1) = n * (n + 1) + 2 * (n + 1) := by
      simp only [Nat.mul_add, Nat.add_mul, Nat.mul_one, Nat.one_mul]; omega
    rw [this, Nat.add_mul_div_left _ _ (by decide)]
    omega

/-- 対の符号の単射性。 -/
theorem natPair_injective {a b c d : Nat} (h : natPair a b = natPair c d) : a = c ∧ b = d := by
  simp only [natPair, ← tri_eq_div] at h
  have hs : a + b = c + d := by
    by_cases h1 : a + b < c + d
    · have := tri_lt h1; omega
    · by_cases h2 : c + d < a + b
      · have := tri_lt h2; omega
      · omega
  rw [hs] at h
  omega

/-! ## 文字列と要素の列の符号 -/

/-- Unicode スカラー値に1を足した桁の基数。0 は列の終端だけに使う（`Release.Order.Atoms` の `Atom.codeBase` と
同じ値）。 -/
def charCodeBase : Nat := 1114113

/-- 文字の列の符号。`Release.Order.Atoms` の `Atom.charsCode` と同じ定義であり、本ファイルを原子の順序より
前に置けるよう、`Release.Order.Atoms` を import せずに定める。 -/
def charListCode : List Char → Nat
  | [] => 0
  | c :: cs => c.toNat + 1 + charCodeBase * charListCode cs

private theorem digit_lt (c : Char) : c.toNat + 1 < charCodeBase := by
  have h := c.valid
  simp only [UInt32.isValidChar, Nat.isValidChar] at h
  change c.val.toNat + 1 < 1114113
  omega

theorem charListCode_injective {cs ds : List Char} (h : charListCode cs = charListCode ds) : cs = ds := by
  induction cs generalizing ds with
  | nil => cases ds <;> simp_all [charListCode] <;> omega
  | cons c cs ih =>
    cases ds with
    | nil => simp [charListCode] at h
    | cons d ds =>
      have hc := digit_lt c
      have hd := digit_lt d
      have hr := congrArg (· % charCodeBase) h
      simp only [charListCode, Nat.add_mod, Nat.mul_mod_right, Nat.add_zero,
        Nat.mod_eq_of_lt hc, Nat.mod_eq_of_lt hd] at hr
      have he : c = d := Char.toNat_inj.mp (by omega)
      subst d
      have ht : charListCode cs = charListCode ds := by
        simp only [charListCode, charCodeBase] at h
        omega
      exact congrArg (c :: ·) (ih ht)

/-- 文字列の符号。 -/
def stringCode (s : String) : Nat := charListCode s.toList

theorem stringCode_injective {s t : String} (h : stringCode s = stringCode t) : s = t :=
  String.toList_inj.mp (charListCode_injective h)

/-- 要素の列（パスとホスト名の `Word`）の符号。空の列は 0、それ以外は 1 以上。 -/
def wordCode : Domain.Word → Nat
  | [] => 0
  | x :: xs => natPair (stringCode x) (wordCode xs) + 1

theorem wordCode_injective {xs ys : Domain.Word} (h : wordCode xs = wordCode ys) : xs = ys := by
  induction xs generalizing ys with
  | nil => cases ys <;> simp_all [wordCode]
  | cons x xs ih =>
    cases ys with
    | nil => simp [wordCode] at h
    | cons y ys =>
      have hp := natPair_injective (show natPair (stringCode x) (wordCode xs) =
          natPair (stringCode y) (wordCode ys) by simp only [wordCode] at h; omega)
      rw [stringCode_injective hp.1, ih hp.2]

/-! ## 対象の領域の各パターンの符号 -/

def pathCode : Domain.PathPattern → Nat
  | .exact s => 2 * wordCode s
  | .tree s => 2 * wordCode s + 1

theorem pathCode_injective {p q : Domain.PathPattern} (h : pathCode p = pathCode q) : p = q := by
  cases p <;> cases q <;> simp only [pathCode] at h
  all_goals first
    | omega
    | exact congrArg _ (wordCode_injective (by omega))

def nameCode : Domain.NamePattern → Nat
  | .exact s => 3 * wordCode s
  | .one s => 3 * wordCode s + 1
  | .many s => 3 * wordCode s + 2

theorem nameCode_injective {p q : Domain.NamePattern} (h : nameCode p = nameCode q) : p = q := by
  cases p <;> cases q <;> simp only [nameCode] at h
  all_goals first
    | omega
    | exact congrArg _ (wordCode_injective (by omega))

def familyCode : Domain.Family → Nat
  | .v4 => 0
  | .v6 => 1

theorem familyCode_injective {f g : Domain.Family} (h : familyCode f = familyCode g) : f = g := by
  cases f <;> cases g <;> simp_all [familyCode]

def ipAddrCode (a : Domain.IPAddr) : Nat := natPair (familyCode a.family) a.bits.val

theorem ipAddrCode_injective {a b : Domain.IPAddr} (h : ipAddrCode a = ipAddrCode b) : a = b := by
  have hp := natPair_injective h
  exact Domain.IPAddr.ext' (familyCode_injective hp.1) hp.2

def cidrCode (c : Domain.CIDR) : Nat :=
  natPair (familyCode c.family) (natPair c.network.val c.prefixLen)

theorem cidrCode_injective {c d : Domain.CIDR} (h : cidrCode c = cidrCode d) : c = d := by
  have hp := natPair_injective h
  have hq := natPair_injective hp.2
  have hf := familyCode_injective hp.1
  cases c with
  | mk fc nc pc =>
    cases d with
    | mk fd nd pd =>
      simp only at hf hq
      subst hf
      obtain ⟨hn, hl⟩ := hq
      subst hl
      exact congrArg (fun n => Domain.CIDR.mk fc n pc) (Fin.ext hn)

def ipCode : Domain.IPPattern → Nat
  | .exact a => 2 * ipAddrCode a
  | .cidr c => 2 * cidrCode c + 1

theorem ipCode_injective {p q : Domain.IPPattern} (h : ipCode p = ipCode q) : p = q := by
  cases p <;> cases q <;> simp only [ipCode] at h
  · exact congrArg _ (ipAddrCode_injective (by omega))
  · omega
  · omega
  · exact congrArg _ (cidrCode_injective (by omega))

def hostCode : Domain.HostPattern → Nat
  | .name p => 2 * nameCode p
  | .ip p => 2 * ipCode p + 1

theorem hostCode_injective {p q : Domain.HostPattern} (h : hostCode p = hostCode q) : p = q := by
  cases p <;> cases q <;> simp only [hostCode] at h
  · exact congrArg _ (nameCode_injective (by omega))
  · omega
  · omega
  · exact congrArg _ (ipCode_injective (by omega))

def portRangeCode (r : Domain.PortRange) : Nat := natPair r.lo.val r.hi.val

theorem portRangeCode_injective {r s : Domain.PortRange} (h : portRangeCode r = portRangeCode s) : r = s := by
  have hp := natPair_injective h
  cases r; cases s
  simp only at hp
  rw [Fin.ext hp.1, Fin.ext hp.2]

def endpointCode (e : Domain.EndpointPattern) : Nat := natPair (hostCode e.host) (portRangeCode e.ports)

theorem endpointCode_injective {e f : Domain.EndpointPattern} (h : endpointCode e = endpointCode f) :
    e = f := by
  have hp := natPair_injective h
  cases e; cases f
  simp only at hp
  rw [hostCode_injective hp.1, portRangeCode_injective hp.2]

/-! ## 範囲と範囲の位置の符号 -/

/-- 閉じた範囲の符号。`top` は 0、非 Top の範囲は種類ごとに 4 を法とする剰余で分ける。 -/
def rangeCode : Domain.Range → Nat
  | .top => 0
  | .path p => 4 * pathCode p + 1
  | .host p => 4 * hostCode p + 2
  | .endpoint p => 4 * endpointCode p + 3

theorem rangeCode_injective {r s : Domain.Range} (h : rangeCode r = rangeCode s) : r = s := by
  cases r <;> cases s <;> simp only [rangeCode] at h
  all_goals first
    | rfl
    | omega
    | exact congrArg _ (pathCode_injective (by omega))
    | exact congrArg _ (hostCode_injective (by omega))
    | exact congrArg _ (endpointCode_injective (by omega))

@[simp] theorem rangeCode_top : rangeCode .top = 0 := rfl

theorem rangeCode_eq_zero_iff {r : Domain.Range} : rangeCode r = 0 ↔ r = .top :=
  ⟨fun h => rangeCode_injective (h.trans rangeCode_top.symm), fun h => h ▸ rfl⟩

/-- 範囲の位置の符号。閉じた範囲は偶数、範囲の変数は奇数。 -/
def ixCode : Signature.Ix → Nat
  | .fixed r => 2 * rangeCode r
  | .rvar i => 2 * i + 1

theorem ixCode_injective {a b : Signature.Ix} (h : ixCode a = ixCode b) : a = b := by
  cases a <;> cases b <;> simp only [ixCode] at h
  · exact congrArg _ (rangeCode_injective (by omega))
  · omega
  · omega
  · exact congrArg _ (by omega)

/-- 明示の Top の位置の符号は 0 である（旧の名前だけの原子の符号の像を後の枝で示すのに使う）。 -/
@[simp] theorem ixCode_top : ixCode Signature.Ix.top = 0 := rfl

/-! ## 比較 -/

/-- 範囲の固定順序。符号の自然数の比較である。 -/
def rangeCompare (r s : Domain.Range) : Ordering := compare (rangeCode r) (rangeCode s)

/-- 範囲の位置の固定順序。符号の自然数の比較である。 -/
def ixCompare (a b : Signature.Ix) : Ordering := compare (ixCode a) (ixCode b)

/-- 反射: 自身との比較は eq。 -/
theorem rangeCompare_self (r : Domain.Range) : rangeCompare r r = .eq := Nat.compare_eq_eq.mpr rfl

/-- eq は構造の等号と同値である。 -/
theorem rangeCompare_eq_iff {r s : Domain.Range} : rangeCompare r s = .eq ↔ r = s :=
  ⟨fun h => rangeCode_injective (Nat.compare_eq_eq.mp h), fun h => h ▸ rangeCompare_self r⟩

/-- 反対称: 両向きの非狭義の比較から構造の等号を得る。 -/
theorem rangeCompare_antisymm {r s : Domain.Range} (h₁ : (rangeCompare r s).isLE)
    (h₂ : (rangeCompare s r).isLE) : r = s := by
  simp only [rangeCompare, Nat.isLE_compare] at h₁ h₂
  exact rangeCode_injective (Nat.le_antisymm h₁ h₂)

/-- 推移: 非狭義の比較の推移。 -/
theorem rangeCompare_isLE_trans {r s u : Domain.Range} (h₁ : (rangeCompare r s).isLE)
    (h₂ : (rangeCompare s u).isLE) : (rangeCompare r u).isLE := by
  simp only [rangeCompare, Nat.isLE_compare] at h₁ h₂ ⊢
  exact Nat.le_trans h₁ h₂

/-- 推移: 狭義の比較の推移。 -/
theorem rangeCompare_lt_trans {r s u : Domain.Range} (h₁ : rangeCompare r s = .lt)
    (h₂ : rangeCompare s u = .lt) : rangeCompare r u = .lt := by
  simp only [rangeCompare, Nat.compare_eq_lt] at h₁ h₂ ⊢
  exact Nat.lt_trans h₁ h₂

theorem rangeCompare_swap (r s : Domain.Range) : (rangeCompare r s).swap = rangeCompare s r :=
  Nat.compare_swap _ _

/-- 全順序: 任意の二つは lt、等号、逆向きの lt のいずれかである。 -/
theorem rangeCompare_total (r s : Domain.Range) :
    rangeCompare r s = .lt ∨ r = s ∨ rangeCompare s r = .lt := by
  simp only [rangeCompare, Nat.compare_eq_lt]
  rcases Nat.lt_trichotomy (rangeCode r) (rangeCode s) with h | h | h
  · exact Or.inl h
  · exact Or.inr (Or.inl (rangeCode_injective h))
  · exact Or.inr (Or.inr h)

instance : LawfulEqCmp rangeCompare where
  compare_self := rangeCompare_self _
  eq_of_compare := rangeCompare_eq_iff.mp

instance : TransCmp rangeCompare where
  eq_swap := (rangeCompare_swap _ _).symm
  isLE_trans := rangeCompare_isLE_trans

theorem ixCompare_self (a : Signature.Ix) : ixCompare a a = .eq := Nat.compare_eq_eq.mpr rfl

theorem ixCompare_eq_iff {a b : Signature.Ix} : ixCompare a b = .eq ↔ a = b :=
  ⟨fun h => ixCode_injective (Nat.compare_eq_eq.mp h), fun h => h ▸ ixCompare_self a⟩

theorem ixCompare_antisymm {a b : Signature.Ix} (h₁ : (ixCompare a b).isLE)
    (h₂ : (ixCompare b a).isLE) : a = b := by
  simp only [ixCompare, Nat.isLE_compare] at h₁ h₂
  exact ixCode_injective (Nat.le_antisymm h₁ h₂)

theorem ixCompare_isLE_trans {a b c : Signature.Ix} (h₁ : (ixCompare a b).isLE)
    (h₂ : (ixCompare b c).isLE) : (ixCompare a c).isLE := by
  simp only [ixCompare, Nat.isLE_compare] at h₁ h₂ ⊢
  exact Nat.le_trans h₁ h₂

theorem ixCompare_lt_trans {a b c : Signature.Ix} (h₁ : ixCompare a b = .lt)
    (h₂ : ixCompare b c = .lt) : ixCompare a c = .lt := by
  simp only [ixCompare, Nat.compare_eq_lt] at h₁ h₂ ⊢
  exact Nat.lt_trans h₁ h₂

theorem ixCompare_swap (a b : Signature.Ix) : (ixCompare a b).swap = ixCompare b a :=
  Nat.compare_swap _ _

theorem ixCompare_total (a b : Signature.Ix) :
    ixCompare a b = .lt ∨ a = b ∨ ixCompare b a = .lt := by
  simp only [ixCompare, Nat.compare_eq_lt]
  rcases Nat.lt_trichotomy (ixCode a) (ixCode b) with h | h | h
  · exact Or.inl h
  · exact Or.inr (Or.inl (ixCode_injective h))
  · exact Or.inr (Or.inr h)

instance : LawfulEqCmp ixCompare where
  compare_self := ixCompare_self _
  eq_of_compare := ixCompare_eq_iff.mp

instance : TransCmp ixCompare where
  eq_swap := (ixCompare_swap _ _).symm
  isLE_trans := ixCompare_isLE_trans

/-- 明示の Top の位置は、全ての位置の中で最小である。 -/
theorem ixCompare_top_isLE (a : Signature.Ix) : (ixCompare Signature.Ix.top a).isLE := by
  simp only [ixCompare, ixCode_top, Nat.isLE_compare]
  exact Nat.zero_le _

/-! ## 名前と範囲の位置の組の符号（後の枝が原子の符号に使う形の確かめ） -/

/-- 名前と範囲の位置の組の符号。後の枝で `Atom.name l ix` の符号を `2 * nameIxCode l ix` とする形を想定する。 -/
def nameIxCode (l : String) (ix : Signature.Ix) : Nat := natPair (stringCode l) (ixCode ix)

theorem nameIxCode_injective {l m : String} {a b : Signature.Ix} (h : nameIxCode l a = nameIxCode m b) :
    l = m ∧ a = b := by
  have hp := natPair_injective h
  exact ⟨stringCode_injective hp.1, ixCode_injective hp.2⟩

/-! ## 小さい具体例 -/

#guard rangeCompare .top (.path (.tree ["data"])) == .lt
#guard rangeCompare (.path (.tree ["data"])) (.path (.tree ["data"])) == .eq
#guard rangeCompare (.path (.exact ["data"])) (.path (.tree ["data"])) != .eq
#guard rangeCompare (.host (.name (.one ["example", "com"]))) (.host (.name (.many ["example", "com"]))) != .eq
#guard ixCompare Signature.Ix.top (.rvar 0) == .lt
#guard ixCompare (.rvar 0) (.rvar 1) == .lt
#guard ixCompare (.fixed (.path (.tree ["data"]))) (.fixed (.path (.tree ["data"]))) == .eq
-- `/32` の CIDR と同じアドレスの完全一致は、正規化の前は符号が違い、正規化の後は同じになる。
#guard rangeCompare (.host (.ip (.cidr (Domain.CIDR.v4 0xC0A8010A 32))))
    (.host (.ip (.exact (Domain.IPAddr.v4 0xC0A8010A)))) != .eq
#guard rangeCompare (Domain.Range.host (.ip (.cidr (Domain.CIDR.v4 0xC0A8010A 32)))).normalize
    (Domain.Range.host (.ip (.exact (Domain.IPAddr.v4 0xC0A8010A)))).normalize == .eq

end Benitoite.Release.Order
