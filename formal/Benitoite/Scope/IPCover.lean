import Benitoite.Scope.Domain

/-!
# IP のパターンの表現・prefix・被覆・非包含

範囲付きのエフェクトの包含は、左の各原子を右のいずれか一原子が丸ごと覆うことで判定する（判断 5）。
本ファイルは、`Scope/Domain.lean` の IP アドレスと CIDR について、L00.02 が L10 へ受け渡した義務のうち
次を定めて示す。

1. 解析済みの数値と族の保持（義務 1）: 数値を上位から並べた固定幅の組（IPv4 は 8 ビットの組が 4 つ、
   IPv6 は 16 ビットの組が 8 つ）との往復。IPv4 を射影した IPv6 アドレスの値は族 `v6` のままである。
2. prefix の区間（義務 2）: 整形式の CIDR では、区間による所属 `CIDR.Mem` と prefix のビットの一致による
   所属 `CIDR.PrefixMem` が一致する。区間は空でない（`lo ≤ hi`）。
3. 同族の区間の包含による被覆（義務 3 の IP）: 判定 `IPPattern.covers?` と、健全性・反射・推移、
   内側が整形式のときの完全性。形は `Scope/Cover.lean` と同じく `Covers`（外側が先）・`covers?`・
   `covers?_spec`・`covers_exact_iff` である。
4. 異族の IP どうしと、ホスト名と IP の非包含（義務 4、DET-01 の g）。IPv4 の `/0` は IPv6 を含まず、
   IPv6 の `/0` は IPv4 を含まない。DNS による相互変換の関数は置かない。

文字列からの解析（IPv4 の十進の四要素、IPv6 の RFC 5952 の正規形、CIDR の字句）は形式化の外側にあり、
本ファイルは解析済みの値だけを扱う（`Domain.lean` の先頭のコメント）。組への分解は字句の規則を定めない。
`HostPattern`・`EndpointPattern`・`Range` 全体の被覆の判定は後の枝（L10.4）が、本ファイルの
`IPPattern.covers_exact_iff` と `Scope/Cover.lean` の同名の補題を使って構成子ごとに組む。

名前の扱いは `Domain.lean` の先頭のコメントに従い、名前空間 `Benitoite.Scope.Domain` の中に置く。
-/

namespace Benitoite.Scope.Domain

/-! ## 固定幅の組への分解（義務 1） -/

namespace Groups

/-- 上位の組から順に並べた幅 `w` ビットの組の列を、一つの数値へまとめる。 -/
def join (w : Nat) : List Nat → Nat
  | [] => 0
  | g :: gs => g * 2 ^ (w * gs.length) + join w gs

/-- 数値の下位 `w * k` ビットを、上位の組から順に `k` 個の幅 `w` ビットの組へ分ける。 -/
def split (w : Nat) : Nat → Nat → List Nat
  | 0, _ => []
  | k + 1, n => n / 2 ^ (w * k) % 2 ^ w :: split w k n

theorem length_split (w k n : Nat) : (split w k n).length = k := by
  induction k with
  | zero => rfl
  | succ k ih => simp [split, ih]

theorem lt_of_mem_split {w k n g : Nat} (h : g ∈ split w k n) : g < 2 ^ w := by
  induction k with
  | zero => simp [split] at h
  | succ k ih =>
    simp only [split, List.mem_cons] at h
    rcases h with rfl | h
    · exact Nat.mod_lt _ (Nat.pow_pos (by decide))
    · exact ih h

private theorem pow_mul_succ (w k : Nat) : 2 ^ (w * (k + 1)) = 2 ^ (w * k) * 2 ^ w := by
  rw [Nat.mul_succ, Nat.pow_add]

theorem join_lt {w : Nat} {gs : List Nat} (h : ∀ g ∈ gs, g < 2 ^ w) :
    join w gs < 2 ^ (w * gs.length) := by
  induction gs with
  | nil => simp [join]
  | cons g gs ih =>
    have hg := h g List.mem_cons_self
    have hr := ih (fun x hx => h x (List.mem_cons_of_mem _ hx))
    simp only [join, List.length_cons, pow_mul_succ]
    have hle : (g + 1) * 2 ^ (w * gs.length) ≤ 2 ^ w * 2 ^ (w * gs.length) := Nat.mul_le_mul_right _ hg
    rw [Nat.succ_mul, Nat.mul_comm (2 ^ w)] at hle
    omega

/-- 組へ分けてまとめ直すと、下位 `w * k` ビットが残る。 -/
theorem join_split (w k n : Nat) : join w (split w k n) = n % 2 ^ (w * k) := by
  induction k with
  | zero => simp [split, join, Nat.mod_one]
  | succ k ih =>
    simp only [split, join, length_split, ih]
    rw [pow_mul_succ, Nat.mod_mul]
    rw [Nat.add_comm (n / 2 ^ (w * k) % 2 ^ w * 2 ^ (w * k)), Nat.mul_comm (n / 2 ^ (w * k) % 2 ^ w)]

/-- 下位 `w * k` ビットより上の部分は、組への分解に影響しない。 -/
theorem split_add_mul (w k n m : Nat) : split w k (n + m * 2 ^ (w * k)) = split w k n := by
  induction k generalizing m with
  | zero => rfl
  | succ k ih =>
    have hP : 0 < 2 ^ (w * k) := Nat.pow_pos (by decide)
    have e : m * 2 ^ (w * (k + 1)) = m * 2 ^ w * 2 ^ (w * k) := by
      rw [pow_mul_succ, Nat.mul_comm (2 ^ (w * k)), Nat.mul_assoc]
    simp only [split]
    rw [e, ih (m * 2 ^ w), Nat.add_mul_div_right _ _ hP, Nat.add_mul_mod_self_right]

/-- 幅に収まる組の列は、まとめてから分けると元に戻る。 -/
theorem split_join {w : Nat} {gs : List Nat} (h : ∀ g ∈ gs, g < 2 ^ w) :
    split w gs.length (join w gs) = gs := by
  induction gs with
  | nil => rfl
  | cons g gs ih =>
    have hg := h g List.mem_cons_self
    have ht : ∀ x ∈ gs, x < 2 ^ w := fun x hx => h x (List.mem_cons_of_mem _ hx)
    have hr := join_lt ht
    have hP : 0 < 2 ^ (w * gs.length) := Nat.pow_pos (by decide)
    simp only [List.length_cons, split, join]
    rw [Nat.add_comm (g * 2 ^ (w * gs.length)), Nat.add_mul_div_right _ _ hP, Nat.div_eq_of_lt hr,
      Nat.zero_add, Nat.mod_eq_of_lt hg, split_add_mul, ih ht]

end Groups

/-- 族ごとの組の幅。IPv4 は 8 ビット（十進の要素）、IPv6 は 16 ビット（16 進の要素）。 -/
def Family.groupWidth : Family → Nat
  | .v4 => 8
  | .v6 => 16

/-- 族ごとの組の数。IPv4 は 4、IPv6 は 8。 -/
def Family.groupCount : Family → Nat
  | .v4 => 4
  | .v6 => 8

theorem Family.groupWidth_mul_groupCount (f : Family) : f.groupWidth * f.groupCount = f.width := by
  cases f <;> rfl

namespace IPAddr

/-- アドレスの値を上位から並べた組。族は値の一部であり、組の数が族を区別する。 -/
def groups (a : IPAddr) : List Nat :=
  Groups.split a.family.groupWidth a.family.groupCount a.bits.val

theorem length_groups (a : IPAddr) : a.groups.length = a.family.groupCount :=
  Groups.length_split _ _ _

theorem lt_of_mem_groups {a : IPAddr} {g : Nat} (h : g ∈ a.groups) : g < 2 ^ a.family.groupWidth :=
  Groups.lt_of_mem_split h

/-- 族と組の列からのアドレスの構築。組の数か組の幅が族に合わなければ `none`。 -/
def ofGroups? (f : Family) (gs : List Nat) : Option IPAddr :=
  if h : gs.length = f.groupCount ∧ ∀ g ∈ gs, g < 2 ^ f.groupWidth then
    some ⟨f, ⟨Groups.join f.groupWidth gs, by
      have := Groups.join_lt h.2
      rwa [h.1, Family.groupWidth_mul_groupCount] at this⟩⟩
  else none

/-- 往復 1: アドレスを組へ分けて構築し直すと、同じ族の同じ値に戻る。 -/
theorem ofGroups?_groups (a : IPAddr) : ofGroups? a.family a.groups = some a := by
  have hc : a.groups.length = a.family.groupCount ∧ ∀ g ∈ a.groups, g < 2 ^ a.family.groupWidth :=
    ⟨length_groups a, fun _ hg => lt_of_mem_groups hg⟩
  unfold ofGroups?
  split
  · refine congrArg some (IPAddr.ext' rfl ?_)
    show Groups.join _ (Groups.split _ _ _) = a.bits.val
    rw [Groups.join_split, Family.groupWidth_mul_groupCount]
    exact Nat.mod_eq_of_lt a.bits.isLt
  · contradiction

/-- 往復 2: 組の列から構築できたアドレスは、指定した族を持ち、組へ分けると元の列に戻る。 -/
theorem groups_of_ofGroups? {f : Family} {gs : List Nat} {a : IPAddr} (h : ofGroups? f gs = some a) :
    a.family = f ∧ a.groups = gs := by
  unfold ofGroups? at h
  split at h
  · rename_i hc
    cases h
    refine ⟨rfl, ?_⟩
    show Groups.split f.groupWidth f.groupCount (Groups.join f.groupWidth gs) = gs
    rw [← hc.1]
    exact Groups.split_join hc.2
  · cases h

/-- 組の列が族に合うときだけ構築できる。 -/
theorem ofGroups?_isSome_iff (f : Family) (gs : List Nat) :
    (ofGroups? f gs).isSome ↔ gs.length = f.groupCount ∧ ∀ g ∈ gs, g < 2 ^ f.groupWidth := by
  unfold ofGroups?
  split <;> simp_all

/-- IPv4 を射影した IPv6 アドレス `::ffff:x.y.z.w` の値。上位 80 ビットが 0、続く 16 ビットが全て 1、
下位 32 ビットが IPv4 の値である。族は `v6` のままで、IPv4 の値と同じものとみなさない（DET-01）。 -/
def mapped (n : Fin (2 ^ 32)) : IPAddr :=
  ⟨.v6, ⟨0xFFFF * 2 ^ 32 + n.val, by have := n.isLt; simp only [Family.width]; omega⟩⟩

@[simp] theorem mapped_family (n : Fin (2 ^ 32)) : (mapped n).family = .v6 := rfl

/-- 射影したアドレスは、どの IPv4 アドレスとも等しくない。 -/
theorem mapped_ne_of_v4 (n : Fin (2 ^ 32)) {a : IPAddr} (ha : a.family = .v4) : mapped n ≠ a := by
  intro h
  have := congrArg IPAddr.family h
  rw [mapped_family, ha] at this
  cases this

/-- 射影したアドレスの値の下位 32 ビットは元の IPv4 の値である（数値は保たれ、族だけが違う）。 -/
theorem mapped_bits_mod (n : Fin (2 ^ 32)) : (mapped n).bits.val % 2 ^ 32 = n.val := by
  show (0xFFFF * 2 ^ 32 + n.val) % 2 ^ 32 = n.val
  have := n.isLt
  omega

end IPAddr

/-! ## prefix の区間（義務 2） -/

namespace CIDR

theorem blockSize_pos (c : CIDR) : 0 < c.blockSize := Nat.pow_pos (by decide)

/-- 区間は空でない。整形式性を要しない。 -/
theorem lo_le_hi (c : CIDR) : c.lo ≤ c.hi := by
  have := blockSize_pos c
  unfold hi lo
  omega

/-- ネットワークの値は区間に所属する。 -/
theorem mem_network (c : CIDR) : c.Mem ⟨c.family, c.network⟩ :=
  ⟨rfl, Nat.le_refl _, lo_le_hi c⟩

/-- 整形式の CIDR では、区間による所属と prefix のビットの一致による所属が一致する。 -/
theorem mem_iff_prefixMem {c : CIDR} (h : c.WF) (a : IPAddr) : c.Mem a ↔ c.PrefixMem a := by
  have hB := blockSize_pos c
  have hn : c.blockSize * (c.network.val / c.blockSize) = c.network.val := by
    have := Nat.div_add_mod c.network.val c.blockSize
    rw [h.2, Nat.add_zero] at this
    exact this
  unfold Mem PrefixMem lo hi
  refine and_congr_right fun _ => ?_
  generalize c.network.val / c.blockSize = q at hn ⊢
  generalize c.blockSize = B at hB hn ⊢
  generalize c.network.val = n at hn ⊢
  generalize a.bits.val = x
  subst hn
  rw [Nat.mul_comm B q]
  constructor
  · rintro ⟨h1, h2⟩
    apply Nat.div_eq_of_lt_le
    · exact h1
    · rw [Nat.succ_mul]; omega
  · intro hx
    have h1 : q * B ≤ x := (Nat.le_div_iff_mul_le hB).mp (Nat.le_of_eq hx.symm)
    have h2 : x < (q + 1) * B := (Nat.div_lt_iff_lt_mul hB).mp (by omega)
    rw [Nat.succ_mul] at h2
    omega

instance (c : CIDR) (a : IPAddr) : Decidable (c.PrefixMem a) := by unfold PrefixMem; infer_instance

end CIDR

/-! ## IP のパターンの区間と被覆（義務 3 の IP） -/

namespace IPPattern

/-- パターンの族。 -/
def family : IPPattern → Family
  | .exact a => a.family
  | .cidr c => c.family

/-- パターンの区間の下端。完全一致は一点の区間である。 -/
def lo : IPPattern → Nat
  | .exact a => a.bits.val
  | .cidr c => c.lo

/-- パターンの区間の上端。 -/
def hi : IPPattern → Nat
  | .exact a => a.bits.val
  | .cidr c => c.hi

theorem lo_le_hi (p : IPPattern) : p.lo ≤ p.hi := by
  cases p with
  | exact a => exact Nat.le_refl _
  | cidr c => exact c.lo_le_hi

theorem lo_lt (p : IPPattern) : p.lo < 2 ^ p.family.width := by
  cases p with
  | exact a => exact a.bits.isLt
  | cidr c => exact c.network.isLt

theorem hi_lt {p : IPPattern} (h : p.WF) : p.hi < 2 ^ p.family.width := by
  cases p with
  | exact a => exact a.bits.isLt
  | cidr c => exact CIDR.hi_lt h

/-- 所属は、族の一致と区間への所属である。整形式性を要しない。 -/
theorem matches_iff_interval (p : IPPattern) (a : IPAddr) :
    p.Matches a ↔ a.family = p.family ∧ p.lo ≤ a.bits.val ∧ a.bits.val ≤ p.hi := by
  cases p with
  | cidr c => rfl
  | exact b =>
    simp only [Matches, family, lo, hi]
    constructor
    · rintro rfl; exact ⟨rfl, Nat.le_refl _, Nat.le_refl _⟩
    · rintro ⟨hf, h1, h2⟩
      exact IPAddr.ext' hf (Nat.le_antisymm h2 h1)

/-- 所属するアドレスはパターンと同じ族を持つ。 -/
theorem family_of_matches {p : IPPattern} {a : IPAddr} (h : p.Matches a) : a.family = p.family :=
  ((matches_iff_interval p a).mp h).1

/-- 区間の下端のアドレス。 -/
def loAddr (p : IPPattern) : IPAddr := ⟨p.family, ⟨p.lo, p.lo_lt⟩⟩

/-- 区間の上端のアドレス（整形式のとき）。 -/
def hiAddr (p : IPPattern) (h : p.WF) : IPAddr := ⟨p.family, ⟨p.hi, hi_lt h⟩⟩

theorem matches_loAddr (p : IPPattern) : p.Matches p.loAddr :=
  (matches_iff_interval p _).mpr ⟨rfl, Nat.le_refl _, p.lo_le_hi⟩

theorem matches_hiAddr {p : IPPattern} (h : p.WF) : p.Matches (p.hiAddr h) :=
  (matches_iff_interval p _).mpr ⟨rfl, p.lo_le_hi, Nat.le_refl _⟩

/-- どの IP のパターンも少なくとも一つのアドレスを含む。 -/
theorem nonempty (p : IPPattern) : ∃ a, p.Matches a := ⟨p.loAddr, p.matches_loAddr⟩

/-- 外側 p が内側 q を覆う（引数は外側が先）。同じ族で、q の区間が p の区間に含まれる。 -/
def Covers (p q : IPPattern) : Prop := q.family = p.family ∧ p.lo ≤ q.lo ∧ q.hi ≤ p.hi

/-- 被覆の判定。 -/
def covers? (p q : IPPattern) : Bool :=
  decide (q.family = p.family) && decide (p.lo ≤ q.lo) && decide (q.hi ≤ p.hi)

theorem covers?_spec (p q : IPPattern) : p.covers? q = true ↔ p.Covers q := by
  simp only [covers?, Covers, Bool.and_eq_true, decide_eq_true_eq, and_assoc]

instance (p q : IPPattern) : Decidable (p.Covers q) := decidable_of_iff _ (covers?_spec p q)

/-- 内側が完全一致のときの被覆は、外側への所属と同じである。 -/
theorem covers_exact_iff (p : IPPattern) (a : IPAddr) : p.Covers (.exact a) ↔ p.Matches a :=
  (matches_iff_interval p a).symm

/-- 健全性: 覆うなら、内側に所属するアドレスは外側に所属する。 -/
theorem Covers.sound {p q : IPPattern} (h : p.Covers q) {a : IPAddr} (ha : q.Matches a) : p.Matches a := by
  rw [matches_iff_interval] at ha ⊢
  obtain ⟨hf, h1, h2⟩ := h
  obtain ⟨af, a1, a2⟩ := ha
  exact ⟨af.trans hf, Nat.le_trans h1 a1, Nat.le_trans a2 h2⟩

theorem Covers.refl (p : IPPattern) : p.Covers p := ⟨rfl, Nat.le_refl _, Nat.le_refl _⟩

theorem Covers.trans {p q r : IPPattern} (h₁ : p.Covers q) (h₂ : q.Covers r) : p.Covers r :=
  ⟨h₂.1.trans h₁.1, Nat.le_trans h₁.2.1 h₂.2.1, Nat.le_trans h₂.2.2 h₁.2.2⟩

/-- 完全性: 内側が整形式なら、所属の包含は被覆を与える。区間の両端のアドレスが内側に所属することを使う。
内側が整形式でない CIDR では上端が幅を超えることがあり、この形の完全性は述べない。 -/
theorem covers_of_sub {p q : IPPattern} (hq : q.WF) (h : ∀ a, q.Matches a → p.Matches a) : p.Covers q := by
  have hl := (matches_iff_interval p _).mp (h _ q.matches_loAddr)
  have hh := (matches_iff_interval p _).mp (h _ (q.matches_hiAddr hq))
  exact ⟨hl.1, hl.2.1, hh.2.2⟩

theorem covers_iff {p q : IPPattern} (hq : q.WF) : p.Covers q ↔ ∀ a, q.Matches a → p.Matches a :=
  ⟨fun h _ ha => h.sound ha, covers_of_sub hq⟩

/-! ### 正規化と区間 -/

theorem normalize_family (p : IPPattern) : p.normalize.family = p.family := by
  cases p with
  | exact a => rfl
  | cidr c =>
    by_cases hp : c.prefixLen = c.family.width
    · rw [normalize_cidr_of_eq hp]; rfl
    · rw [normalize_cidr_of_ne hp]

theorem normalize_lo (p : IPPattern) : p.normalize.lo = p.lo := by
  cases p with
  | exact a => rfl
  | cidr c =>
    by_cases hp : c.prefixLen = c.family.width
    · rw [normalize_cidr_of_eq hp]; rfl
    · rw [normalize_cidr_of_ne hp]

theorem normalize_hi (p : IPPattern) : p.normalize.hi = p.hi := by
  cases p with
  | exact a => rfl
  | cidr c =>
    by_cases hp : c.prefixLen = c.family.width
    · rw [normalize_cidr_of_eq hp]
      simp only [hi, CIDR.hi, CIDR.blockSize, CIDR.hostBits, hp, Nat.sub_self, Nat.pow_zero,
        Nat.add_sub_cancel]
    · rw [normalize_cidr_of_ne hp]

/-- 正規化の前後で被覆は変わらない（外側・内側のどちらを正規化しても）。 -/
theorem covers_normalize_iff (p q : IPPattern) : p.normalize.Covers q.normalize ↔ p.Covers q := by
  simp only [Covers, normalize_family, normalize_lo, normalize_hi]

/-! ### 異族の非包含（義務 4） -/

/-- 族の違うパターンは覆わない。 -/
theorem not_covers_of_family_ne {p q : IPPattern} (h : q.family ≠ p.family) : ¬ p.Covers q :=
  fun hc => h hc.1

/-- 族の違うパターンは、共通のアドレスを持たない。 -/
theorem disjoint_of_family_ne {p q : IPPattern} (h : p.family ≠ q.family) (a : IPAddr) :
    ¬ (p.Matches a ∧ q.Matches a) :=
  fun ⟨hp, hq⟩ => h ((family_of_matches hp).symm.trans (family_of_matches hq))

/-- 族の違うパターンは、所属の上でも互いに包含しない。 -/
theorem not_sub_of_family_ne {p q : IPPattern} (h : p.family ≠ q.family) :
    ¬ ∀ a, p.Matches a → q.Matches a :=
  fun hs => disjoint_of_family_ne h _ ⟨p.matches_loAddr, hs _ p.matches_loAddr⟩

/-- IPv4 のパターンは IPv4 を射影した IPv6 アドレスを含まない。 -/
theorem not_matches_mapped {p : IPPattern} (hp : p.family = .v4) (n : Fin (2 ^ 32)) :
    ¬ p.Matches (IPAddr.mapped n) := by
  intro h
  have := family_of_matches h
  rw [IPAddr.mapped_family, hp] at this
  cases this

/-- 族 f の `/0`（`0.0.0.0/0`・`::/0`）。 -/
def zero (f : Family) : IPPattern := .cidr ⟨f, ⟨0, Nat.pow_pos (by decide)⟩, 0⟩

theorem zero_wf (f : Family) : (zero f).WF := by
  refine ⟨Nat.zero_le _, ?_⟩
  show 0 % _ = 0
  exact Nat.zero_mod _

/-- 族 f の `/0` は、族 f のアドレスをちょうど全て含む。IPv4 の `/0` は IPv6 のアドレス（射影した
アドレスを含む）を含まず、IPv6 の `/0` は IPv4 のアドレスを含まない。 -/
theorem zero_matches_iff (f : Family) (a : IPAddr) : (zero f).Matches a ↔ a.family = f := by
  rw [matches_iff_interval]
  refine ⟨fun h => h.1, fun h => ⟨h, Nat.zero_le _, ?_⟩⟩
  obtain ⟨fa, v⟩ := a
  simp only at h
  subst h
  have := v.isLt
  show v.val ≤ 0 + 2 ^ (fa.width - 0) - 1
  rw [Nat.sub_zero, Nat.zero_add]
  omega

/-- 族 f の `/0` は、族 f の整形式のパターンをちょうど全て覆う。 -/
theorem zero_covers_iff (f : Family) {q : IPPattern} (hq : q.WF) : (zero f).Covers q ↔ q.family = f := by
  rw [covers_iff hq]
  constructor
  · intro h
    exact (zero_matches_iff f q.loAddr).mp (h _ q.matches_loAddr)
  · intro hf a ha
    exact (zero_matches_iff f a).mpr ((family_of_matches ha).trans hf)

end IPPattern

/-! ## ホスト名と IP の非包含（義務 4、DET-01 の g） -/

namespace NamePattern

/-- パターンに所属するラベル列の一つ。 -/
def witness : NamePattern → Word
  | .exact s => s
  | .one s => "a" :: s
  | .many s => "a" :: s

theorem matches_witness (p : NamePattern) : p.Matches p.witness := by
  cases p with
  | exact s => rfl
  | one s => exact ⟨"a", rfl⟩
  | many s => exact ⟨["a"], List.cons_ne_nil _ _, rfl⟩

/-- どのホスト名のパターンも少なくとも一つのラベル列を含む。 -/
theorem nonempty (p : NamePattern) : ∃ w, p.Matches w := ⟨p.witness, p.matches_witness⟩

end NamePattern

namespace HostPattern

/-- ホスト名のパターンと IP のパターンは、共通の対象を持たない。 -/
theorem name_ip_disjoint (p : NamePattern) (q : IPPattern) (t : HostTarget) :
    ¬ ((HostPattern.name p).Matches t ∧ (HostPattern.ip q).Matches t) := by
  cases t <;> simp [Matches]

/-- IP のパターンはホスト名のパターンに包含されない。 -/
theorem ip_not_sub_name (q : IPPattern) (p : NamePattern) :
    ¬ ∀ t, (HostPattern.ip q).Matches t → (HostPattern.name p).Matches t :=
  fun h => h (.ip q.loAddr) q.matches_loAddr

/-- ホスト名のパターンは IP のパターンに包含されない。 -/
theorem name_not_sub_ip (p : NamePattern) (q : IPPattern) :
    ¬ ∀ t, (HostPattern.name p).Matches t → (HostPattern.ip q).Matches t :=
  fun h => h (.name p.witness) p.matches_witness

/-- 族の違う IP のパターンは、ホストのパターンとしても包含されない。 -/
theorem ip_not_sub_ip_of_family_ne {p q : IPPattern} (h : p.family ≠ q.family) :
    ¬ ∀ t, (HostPattern.ip p).Matches t → (HostPattern.ip q).Matches t :=
  fun hs => IPPattern.not_sub_of_family_ne h fun a ha => hs (.ip a) ha

end HostPattern

namespace Range

/-- 範囲の意味の包含でも、IP の範囲はホスト名の範囲に含まれない。 -/
theorem host_ip_not_sub_host_name (q : IPPattern) (p : NamePattern) :
    ¬ (Range.host (.ip q)).Sub (.host (.name p)) :=
  fun h => HostPattern.ip_not_sub_name q p fun t ht => h (.host t) ht

/-- 範囲の意味の包含でも、ホスト名の範囲は IP の範囲に含まれない。 -/
theorem host_name_not_sub_host_ip (p : NamePattern) (q : IPPattern) :
    ¬ (Range.host (.name p)).Sub (.host (.ip q)) :=
  fun h => HostPattern.name_not_sub_ip p q fun t ht => h (.host t) ht

/-- 範囲の意味の包含でも、族の違う IP の範囲は互いに含まれない。 -/
theorem host_ip_not_sub_of_family_ne {p q : IPPattern} (hf : p.family ≠ q.family) :
    ¬ (Range.host (.ip p)).Sub (.host (.ip q)) :=
  fun h => HostPattern.ip_not_sub_ip_of_family_ne hf fun t ht => h (.host t) ht

end Range

/-! ## 小さい具体例

`#guard` はコンパイルした判定を評価し、カーネルの展開に頼らない。
-/

private def lan16 : IPPattern := .cidr (CIDR.v4 0xC0A80000 16)     -- 192.168.0.0/16
private def lan24 : IPPattern := .cidr (CIDR.v4 0xC0A80100 24)     -- 192.168.1.0/24
private def lan24b : IPPattern := .cidr (CIDR.v4 0xC0A80200 24)    -- 192.168.2.0/24
private def lanHost : IPPattern := .exact (IPAddr.v4 0xC0A80114)   -- 192.168.1.20
private def mappedV4 : IPAddr := IPAddr.mapped ⟨0xC0000201, by decide⟩  -- ::ffff:192.0.2.1

-- 組との往復。`192.0.2.1` は四つの 8 ビットの組、射影したアドレスは八つの 16 ビットの組。
#guard (IPAddr.v4 0xC0000201).groups == [192, 0, 2, 1]
#guard mappedV4.groups == [0, 0, 0, 0, 0, 0xFFFF, 0xC000, 0x0201]
#guard IPAddr.ofGroups? .v4 [192, 0, 2, 1] == some (IPAddr.v4 0xC0000201)
#guard IPAddr.ofGroups? .v6 [0, 0, 0, 0, 0, 0xFFFF, 0xC000, 0x0201] == some mappedV4
#guard (IPAddr.ofGroups? .v4 [192, 0, 2, 256]).isNone && (IPAddr.ofGroups? .v4 [192, 0, 2]).isNone
-- 射影したアドレスは族 v6 のままで、同じ数値の IPv4 アドレスとは別の値である。
#guard mappedV4.family == .v6 && mappedV4 != IPAddr.v4 0xC0000201
-- prefix の区間: `192.168.1.0/24` の所属と prefix の一致。
#guard decide ((CIDR.v4 0xC0A80100 24).PrefixMem (IPAddr.v4 0xC0A801FF))
#guard !decide ((CIDR.v4 0xC0A80100 24).PrefixMem (IPAddr.v4 0xC0A80200))
-- 同族の区間の包含。
#guard lan16.covers? lan24 && !lan24.covers? lan16
#guard lan24.covers? lanHost && !lan24b.covers? lanHost && !lan24.covers? lan24b
#guard (IPPattern.zero .v4).covers? lan16 && (IPPattern.zero .v6).covers? (.exact mappedV4)
-- `/32` と完全一致は互いに覆う。
#guard (IPPattern.cidr (CIDR.v4 0xC0A80114 32)).covers? lanHost
#guard lanHost.covers? (.cidr (CIDR.v4 0xC0A80114 32))
-- 異族: IPv4 の `/0` は IPv6（射影したアドレスを含む）を覆わず、IPv6 の `/0` は IPv4 を覆わない。
#guard !(IPPattern.zero .v4).covers? (.exact mappedV4)
#guard !(IPPattern.zero .v4).covers? (.cidr (CIDR.v6 0xFFFF00000000 96))
#guard !(IPPattern.zero .v6).covers? lanHost && !(IPPattern.zero .v6).covers? lan16
#guard !decide ((IPPattern.zero .v4).Matches mappedV4)
#guard !decide ((IPPattern.zero .v6).Matches (IPAddr.v4 0xC0000201))
-- 射影の prefix `::ffff:0:0/96` は射影したアドレスを含むが、IPv4 のアドレスを含まない。
#guard (IPPattern.cidr (CIDR.v6 0xFFFF00000000 96)).covers? (.exact mappedV4)
#guard !(IPPattern.cidr (CIDR.v6 0xFFFF00000000 96)).covers? (.exact (IPAddr.v4 0xC0000201))
-- ホスト名と IP: 互いに所属しない。
#guard !decide ((HostPattern.name (.many ["0", "0", "1"])).Matches (.ip (IPAddr.v4 0x7F000001)))
#guard !decide ((HostPattern.ip (IPPattern.zero .v4)).Matches (.name ["localhost"]))

end Benitoite.Scope.Domain
