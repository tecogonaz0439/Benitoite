import Benitoite.Scope.Cover
import Benitoite.Scope.IPCover

/-!
# 一原子の被覆の判定: ポート・エンドポイント・ホストのパターン・`Range` 全体

範囲付きのエフェクトの包含は、左の各原子を右のいずれか一原子が丸ごと覆うことで判定する（判断 5）。
本ファイルは、`Scope/Cover.lean`（パスとホスト名）と `Scope/IPCover.lean`（IP）の一原子の被覆を
構成子ごとに組み、L00.02 が L10 へ受け渡した義務のうち次を定めて示す。

1. ポートの閉区間の被覆（区間の包含）と、エンドポイント（ホストのパターンとポートの区間の積）の被覆。
   健全性・反射・推移と、内側が整形式のときの完全性（義務 5）。
2. ホストのパターンの被覆（ホスト名どうし・IP どうしだけを比べ、ホスト名と IP の組は覆わない）。
3. `Range` 全体の被覆の判定と、健全性・反射・推移（義務 3 の全体）。Top は全ての範囲を覆い、非 Top は
   Top を覆わない。非 Top は同じ種類の範囲だけを覆う。
4. 和による被覆を判定しないこと（判断 5）。`0..9` の各ポートは `0..4` か `5..9` に所属するが、どちらの
   一区間も `0..9` を覆わない。
5. 正規化と被覆の両立（義務 6 のうち範囲の部分）。正規化の前後で被覆は変わらない。正規形の範囲どうしでは
   相互の被覆が構造の等号を与え、整形式の範囲を同じ正規形へ写すのは所属が一致する範囲だけである。
   `/32`・`/128` の CIDR と同じアドレスの完全一致のほかに範囲を同一視せず、CIDR を合併しない。

健全性の形: `r.Covers s` の健全性は意味の包含 `s.Sub r`（内側が先。`Range.Mem` についての包含）で述べる。
被覆の判定は名前の種類を見ず、`Range.Sub` は全ての種類 `k` について種類に相対的な所属 `Range.MemK k` の包含を
与える（`Covers.sound_memK`）ので、`Sub` の形がより強い言明になるためである。名前から種類への関数 κ を使う
許可の関係は L10.5 が本ファイルの `Covers.sound_memK` を使って定める。完全性は `Sub` の形では内側の
整形式性 `Range.WF` を前提に成り立つ（`covers_iff`）。`MemK` の形では内側が非 Top のときに限って成り立ち
（`covers_iff_memK`）、内側が Top のときは成り立たない（`tree_root_memK_not_covers_top`。`/**` は種類 `path` の
全ての対象を含むが、Top を覆わない）。

名前の扱いは `Domain.lean` の先頭のコメントに従い、名前空間 `Benitoite.Scope.Domain` の中に置く。
-/

namespace Benitoite.Scope.Domain

/-! ## ポートの閉区間 -/

namespace PortRange

/-- 外側 p が内側 q を覆う（引数は外側が先）。q の区間が p の区間に含まれる。 -/
def Covers (p q : PortRange) : Prop := p.lo ≤ q.lo ∧ q.hi ≤ p.hi

/-- 被覆の判定。 -/
def covers? (p q : PortRange) : Bool := decide (p.lo ≤ q.lo) && decide (q.hi ≤ p.hi)

theorem covers?_spec (p q : PortRange) : p.covers? q = true ↔ p.Covers q := by
  simp only [covers?, Covers, Bool.and_eq_true, decide_eq_true_eq]

instance (p q : PortRange) : Decidable (p.Covers q) := decidable_of_iff _ (covers?_spec p q)

/-- 健全性: 覆うなら、内側に所属するポートは外側に所属する。 -/
theorem Covers.sound {p q : PortRange} (h : p.Covers q) {x : Port} (hx : q.Mem x) : p.Mem x :=
  ⟨Fin.le_trans h.1 hx.1, Fin.le_trans hx.2 h.2⟩

theorem Covers.refl (p : PortRange) : p.Covers p := ⟨Fin.le_refl _, Fin.le_refl _⟩

theorem Covers.trans {p q r : PortRange} (h₁ : p.Covers q) (h₂ : q.Covers r) : p.Covers r :=
  ⟨Fin.le_trans h₁.1 h₂.1, Fin.le_trans h₂.2 h₁.2⟩

/-- 相互に覆う区間は等しい。 -/
theorem Covers.antisymm {p q : PortRange} (h₁ : p.Covers q) (h₂ : q.Covers p) : p = q := by
  cases p with
  | mk a b =>
    cases q with
    | mk c d =>
      simp only [Covers] at h₁ h₂
      rw [Fin.le_antisymm h₁.1 h₂.1, Fin.le_antisymm h₂.2 h₁.2]

theorem mem_lo {r : PortRange} (h : r.WF) : r.Mem r.lo := ⟨Fin.le_refl _, h⟩

theorem mem_hi {r : PortRange} (h : r.WF) : r.Mem r.hi := ⟨h, Fin.le_refl _⟩

/-- 整形式の区間は空でない。 -/
theorem nonempty {r : PortRange} (h : r.WF) : ∃ x, r.Mem x := ⟨r.lo, mem_lo h⟩

/-- 完全性: 内側が整形式なら、所属の包含は被覆を与える。区間の両端のポートが内側に所属することを使う。 -/
theorem covers_of_sub {p q : PortRange} (hq : q.WF) (h : ∀ x, q.Mem x → p.Mem x) : p.Covers q :=
  ⟨(h _ (mem_lo hq)).1, (h _ (mem_hi hq)).2⟩

theorem covers_iff {p q : PortRange} (hq : q.WF) : p.Covers q ↔ ∀ x, q.Mem x → p.Mem x :=
  ⟨fun h _ hx => h.sound hx, covers_of_sub hq⟩

/-- 完全性に内側の整形式性が要ること: 空の区間 `5..3` は所属の上では `0..0` に含まれるが、覆われない。 -/
theorem empty_sub_not_covers :
    (∀ x, (⟨5, 3⟩ : PortRange).Mem x → (⟨0, 0⟩ : PortRange).Mem x) ∧
      ¬ (⟨0, 0⟩ : PortRange).Covers ⟨5, 3⟩ := by
  refine ⟨fun x hx => ?_, by decide⟩
  simp only [Mem, Fin.le_def] at hx
  omega

/-- 和による被覆を判定しない（判断 5）。`0..9` の各ポートは `0..4` か `5..9` に所属するが、どちらの一区間も
`0..9` を覆わない。 -/
theorem union_not_covers :
    (∀ x, (⟨0, 9⟩ : PortRange).Mem x → (⟨0, 4⟩ : PortRange).Mem x ∨ (⟨5, 9⟩ : PortRange).Mem x) ∧
      ¬ (⟨0, 4⟩ : PortRange).Covers ⟨0, 9⟩ ∧ ¬ (⟨5, 9⟩ : PortRange).Covers ⟨0, 9⟩ := by
  refine ⟨fun x hx => ?_, by decide, by decide⟩
  simp only [Mem, Fin.le_def] at hx ⊢
  omega

end PortRange

/-! ## パスとホスト名の補足 -/

namespace PathPattern

/-- どのパスのパターンも幹自身を含む。 -/
theorem nonempty (p : PathPattern) : ∃ w, p.Matches w := by
  cases p with
  | exact s => exact ⟨s, rfl⟩
  | tree s => exact ⟨s, [], by simp⟩

/-- 相互に覆うパスのパターンは等しい。 -/
theorem Covers.antisymm {p q : PathPattern} (h₁ : p.Covers q) (h₂ : q.Covers p) : p = q := by
  match p, q, h₁, h₂ with
  | .exact _, .exact _, h, _ => rw [h]
  | .tree s, .tree t, ⟨r, hr⟩, ⟨r', hr'⟩ =>
    have hl : r.length = 0 := by
      have h1 := congrArg List.length hr
      have h2 := congrArg List.length hr'
      simp only [List.length_append] at h1 h2
      omega
    rw [List.eq_nil_of_length_eq_zero hl, List.append_nil] at hr
    rw [hr]

end PathPattern

namespace NamePattern

/-- 相互に覆うホスト名のパターンは等しい。 -/
theorem Covers.antisymm {p q : NamePattern} (h₁ : p.Covers q) (h₂ : q.Covers p) : p = q := by
  match p, q, h₁, h₂ with
  | .exact _, .exact _, h, _ => rw [h]
  | .one _, .one _, h, _ => rw [h]
  | .many s, .many t, ⟨r, hr⟩, ⟨r', hr'⟩ =>
    have hl : r.length = 0 := by
      have h1 := congrArg List.length hr
      have h2 := congrArg List.length hr'
      simp only [List.length_append] at h1 h2
      omega
    rw [List.eq_nil_of_length_eq_zero hl, List.nil_append] at hr
    rw [hr]

end NamePattern

/-! ## IP のパターンの補足 -/

namespace CIDR

/-- 族・ネットワークの数値・prefix の長さが一致する CIDR は等しい。 -/
theorem ext' {c d : CIDR} (hf : c.family = d.family) (hn : c.network.val = d.network.val)
    (hp : c.prefixLen = d.prefixLen) : c = d := by
  cases c with
  | mk fc nc pc =>
    cases d with
    | mk fd nd pd =>
      simp only at hf hn hp
      subst hf
      subst hp
      obtain rfl : nc = nd := Fin.ext hn
      rfl

/-- prefix が幅より短い CIDR の区間は二点以上を含む。 -/
theorem lo_lt_hi {c : CIDR} (h : c.prefixLen < c.family.width) : c.lo < c.hi := by
  have hb : 1 < c.blockSize := Nat.one_lt_two_pow (by simp only [hostBits]; omega)
  simp only [lo, hi]
  omega

end CIDR

namespace IPPattern

/-- 外側だけを正規化しても被覆は変わらない。 -/
theorem covers_normalize_left (p q : IPPattern) : p.normalize.Covers q ↔ p.Covers q := by
  simp only [Covers, normalize_family, normalize_lo, normalize_hi]

/-- 内側だけを正規化しても被覆は変わらない。 -/
theorem covers_normalize_right (p q : IPPattern) : p.Covers q.normalize ↔ p.Covers q := by
  simp only [Covers, normalize_family, normalize_lo, normalize_hi]

/-- 正規形の IP のパターンどうしでは、相互の被覆は構造の等号を与える。正規形でない `/32`・`/128` の CIDR と
同じアドレスの完全一致は互いに覆うが等しくないので、正規形の前提は外せない（`cidr_full_exact`）。 -/
theorem Covers.antisymm {p q : IPPattern} (hp : p.Canonical) (hq : q.Canonical)
    (h₁ : p.Covers q) (h₂ : q.Covers p) : p = q := by
  have hlo : p.lo = q.lo := Nat.le_antisymm h₁.2.1 h₂.2.1
  have hhi : p.hi = q.hi := Nat.le_antisymm h₂.2.2 h₁.2.2
  have hf : q.family = p.family := h₁.1
  match p, q, hp, hq, hlo, hhi, hf with
  | .exact a, .exact b, _, _, hlo, _, hf => exact congrArg IPPattern.exact (IPAddr.ext' hf.symm hlo)
  | .exact a, .cidr c, _, hq, hlo, hhi, _ =>
    have := CIDR.lo_lt_hi hq
    simp only [lo, hi] at hlo hhi
    omega
  | .cidr c, .exact a, hp, _, hlo, hhi, _ =>
    have := CIDR.lo_lt_hi hp
    simp only [lo, hi] at hlo hhi
    omega
  | .cidr c, .cidr d, hp, hq, hlo, hhi, hf =>
    simp only [Canonical] at hp hq
    simp only [family, lo, hi, CIDR.lo, CIDR.hi] at hlo hhi hf
    have hbc : 0 < c.blockSize := CIDR.blockSize_pos c
    have hbd : 0 < d.blockSize := CIDR.blockSize_pos d
    have hb : c.blockSize = d.blockSize := by omega
    simp only [CIDR.blockSize] at hb
    have hh : c.hostBits = d.hostBits := (Nat.pow_right_inj (by decide)).mp hb
    simp only [CIDR.hostBits] at hh
    rw [hf] at hh hq
    exact congrArg IPPattern.cidr (CIDR.ext' hf.symm hlo (by omega))

/-- `/32`・`/128` の CIDR（prefix の長さが族の幅に等しい CIDR）と同じアドレスの完全一致は、互いに覆うが
構造の上では別のパターンであり、正規化で同じパターンになる。 -/
theorem cidr_full_exact (f : Family) (n : Fin (2 ^ f.width)) :
    IPPattern.cidr ⟨f, n, f.width⟩ ≠ .exact ⟨f, n⟩ ∧
      (IPPattern.cidr ⟨f, n, f.width⟩).Covers (.exact ⟨f, n⟩) ∧
      (IPPattern.exact ⟨f, n⟩).Covers (.cidr ⟨f, n, f.width⟩) ∧
      (IPPattern.cidr ⟨f, n, f.width⟩).normalize = .exact ⟨f, n⟩ := by
  have hhi : (IPPattern.cidr ⟨f, n, f.width⟩).hi = n.val := by
    simp only [hi, CIDR.hi, CIDR.blockSize, CIDR.hostBits, Nat.sub_self, Nat.pow_zero,
      Nat.add_sub_cancel]
  refine ⟨fun h => IPPattern.noConfusion h, ?_, ?_, normalize_cidr_of_eq (c := ⟨f, n, f.width⟩) rfl⟩
  · refine ⟨rfl, Nat.le_refl _, ?_⟩
    rw [hhi]; exact Nat.le_refl _
  · refine ⟨rfl, Nat.le_refl _, ?_⟩
    rw [hhi]; exact Nat.le_refl _

end IPPattern

/-! ## ホストのパターン -/

namespace HostPattern

/-- 外側 p が内側 q を覆う。ホスト名のパターンどうしと IP のパターンどうしだけを比べ、ホスト名と IP の組は
覆わない（DET-01 の g。DNS による相互変換をしない）。 -/
def Covers : HostPattern → HostPattern → Prop
  | .name p, .name q => p.Covers q
  | .ip p, .ip q => p.Covers q
  | .name _, .ip _ => False
  | .ip _, .name _ => False

/-- 被覆の判定。 -/
def covers? : HostPattern → HostPattern → Bool
  | .name p, .name q => p.covers? q
  | .ip p, .ip q => p.covers? q
  | .name _, .ip _ => false
  | .ip _, .name _ => false

theorem covers?_spec (p q : HostPattern) : p.covers? q = true ↔ p.Covers q := by
  cases p <;> cases q <;>
    simp only [covers?, Covers, NamePattern.covers?_spec, IPPattern.covers?_spec, Bool.false_eq_true]

instance (p q : HostPattern) : Decidable (p.Covers q) := decidable_of_iff _ (covers?_spec p q)

/-- 内側がホスト名の完全一致のときの被覆は、外側への所属と同じである。 -/
theorem covers_name_exact_iff (p : HostPattern) (w : Word) :
    p.Covers (.name (.exact w)) ↔ p.Matches (.name w) := by
  cases p with
  | name p => exact NamePattern.covers_exact_iff p w
  | ip p => exact Iff.rfl

/-- 内側が IP の完全一致のときの被覆は、外側への所属と同じである。 -/
theorem covers_ip_exact_iff (p : HostPattern) (a : IPAddr) :
    p.Covers (.ip (.exact a)) ↔ p.Matches (.ip a) := by
  cases p with
  | name p => exact Iff.rfl
  | ip p => exact IPPattern.covers_exact_iff p a

/-- 健全性: 覆うなら、内側に所属する対象は外側に所属する。 -/
theorem Covers.sound {p q : HostPattern} (h : p.Covers q) {t : HostTarget} (ht : q.Matches t) :
    p.Matches t := by
  cases p <;> cases q <;> cases t <;> simp only [Covers, Matches] at h ht ⊢
  · exact NamePattern.Covers.sound h ht
  · exact IPPattern.Covers.sound h ht

theorem Covers.refl (p : HostPattern) : p.Covers p := by
  cases p with
  | name p => exact NamePattern.Covers.refl p
  | ip p => exact IPPattern.Covers.refl p

theorem Covers.trans {p q r : HostPattern} (h₁ : p.Covers q) (h₂ : q.Covers r) : p.Covers r := by
  cases p <;> cases q <;> cases r <;> simp only [Covers] at h₁ h₂ ⊢
  · exact NamePattern.Covers.trans h₁ h₂
  · exact IPPattern.Covers.trans h₁ h₂

/-- 正規形のホストのパターンどうしでは、相互の被覆は構造の等号を与える。 -/
theorem Covers.antisymm {p q : HostPattern} (hp : p.Canonical) (hq : q.Canonical)
    (h₁ : p.Covers q) (h₂ : q.Covers p) : p = q := by
  match p, q, hp, hq, h₁, h₂ with
  | .name _, .name _, _, _, h₁, h₂ => exact congrArg HostPattern.name (NamePattern.Covers.antisymm h₁ h₂)
  | .ip _, .ip _, hp, hq, h₁, h₂ => exact congrArg HostPattern.ip (IPPattern.Covers.antisymm hp hq h₁ h₂)

/-- どのホストのパターンも少なくとも一つの対象を含む。 -/
theorem nonempty (p : HostPattern) : ∃ t, p.Matches t := by
  cases p with
  | name p => exact ⟨.name p.witness, p.matches_witness⟩
  | ip p => exact ⟨.ip p.loAddr, p.matches_loAddr⟩

/-- 完全性: 内側が整形式なら、所属の包含は被覆を与える。ホスト名と IP の組は、どちらのパターンも空でなく
共通の対象を持たないので、所属の上でも包含しない。 -/
theorem covers_of_sub {p q : HostPattern} (hq : q.WF) (h : ∀ t, q.Matches t → p.Matches t) :
    p.Covers q := by
  cases p with
  | name p =>
    cases q with
    | name q => exact NamePattern.covers_of_sub fun w hw => h (.name w) hw
    | ip q => exact (ip_not_sub_name q p h).elim
  | ip p =>
    cases q with
    | name q => exact (name_not_sub_ip q p h).elim
    | ip q => exact IPPattern.covers_of_sub hq fun a ha => h (.ip a) ha

theorem covers_iff {p q : HostPattern} (hq : q.WF) : p.Covers q ↔ ∀ t, q.Matches t → p.Matches t :=
  ⟨fun h _ ht => h.sound ht, covers_of_sub hq⟩

theorem covers_normalize_left (p q : HostPattern) : p.normalize.Covers q ↔ p.Covers q := by
  cases p <;> cases q <;> simp only [normalize, Covers]
  exact IPPattern.covers_normalize_left _ _

theorem covers_normalize_right (p q : HostPattern) : p.Covers q.normalize ↔ p.Covers q := by
  cases p <;> cases q <;> simp only [normalize, Covers]
  exact IPPattern.covers_normalize_right _ _

/-- 正規化の前後で被覆は変わらない（外側・内側の両方を正規化しても）。 -/
theorem covers_normalize_iff (p q : HostPattern) : p.normalize.Covers q.normalize ↔ p.Covers q :=
  (covers_normalize_left p q.normalize).trans (covers_normalize_right p q)

theorem normalize_of_canonical {p : HostPattern} (h : p.Canonical) : p.normalize = p := by
  cases p with
  | name p => rfl
  | ip p => exact congrArg HostPattern.ip (IPPattern.normalize_of_canonical h)

theorem normalize_idem (p : HostPattern) : p.normalize.normalize = p.normalize := by
  cases p with
  | name p => rfl
  | ip p => exact congrArg HostPattern.ip (IPPattern.normalize_idem p)

end HostPattern

/-! ## エンドポイント（義務 5） -/

namespace EndpointPattern

/-- 外側 p が内側 q を覆う。ホストのパターンの被覆と、ポートの区間の包含の両方である（積の被覆）。 -/
def Covers (p q : EndpointPattern) : Prop := p.host.Covers q.host ∧ p.ports.Covers q.ports

/-- 被覆の判定。 -/
def covers? (p q : EndpointPattern) : Bool := p.host.covers? q.host && p.ports.covers? q.ports

theorem covers?_spec (p q : EndpointPattern) : p.covers? q = true ↔ p.Covers q := by
  simp only [covers?, Covers, Bool.and_eq_true, HostPattern.covers?_spec, PortRange.covers?_spec]

instance (p q : EndpointPattern) : Decidable (p.Covers q) := decidable_of_iff _ (covers?_spec p q)

/-- 健全性: ホストの被覆とポートの区間の包含から、エンドポイントの所属の包含が従う（義務 5）。 -/
theorem Covers.sound {p q : EndpointPattern} (h : p.Covers q) {t : Endpoint} (ht : q.Matches t) :
    p.Matches t :=
  ⟨h.1.sound ht.1, h.2.sound ht.2⟩

theorem Covers.refl (p : EndpointPattern) : p.Covers p := ⟨HostPattern.Covers.refl _, PortRange.Covers.refl _⟩

theorem Covers.trans {p q r : EndpointPattern} (h₁ : p.Covers q) (h₂ : q.Covers r) : p.Covers r :=
  ⟨h₁.1.trans h₂.1, h₁.2.trans h₂.2⟩

theorem Covers.antisymm {p q : EndpointPattern} (hp : p.host.Canonical) (hq : q.host.Canonical)
    (h₁ : p.Covers q) (h₂ : q.Covers p) : p = q := by
  cases p with
  | mk hp' pp =>
    cases q with
    | mk hq' pq =>
      have e1 := HostPattern.Covers.antisymm hp hq h₁.1 h₂.1
      have e2 := PortRange.Covers.antisymm h₁.2 h₂.2
      simp only at e1 e2
      rw [e1, e2]

/-- 整形式のエンドポイントのパターンは空でない。 -/
theorem nonempty {e : EndpointPattern} (h : e.WF) : ∃ t, e.Matches t := by
  obtain ⟨t, ht⟩ := e.host.nonempty
  obtain ⟨x, hx⟩ := PortRange.nonempty h.2
  exact ⟨⟨t, x⟩, ht, hx⟩

/-- 完全性: 内側が整形式なら、所属の包含は被覆を与える。積の各成分が空でないことを使う。 -/
theorem covers_of_sub {p q : EndpointPattern} (hq : q.WF) (h : ∀ t, q.Matches t → p.Matches t) :
    p.Covers q := by
  obtain ⟨t0, ht0⟩ := q.host.nonempty
  obtain ⟨x0, hx0⟩ := PortRange.nonempty hq.2
  exact ⟨HostPattern.covers_of_sub hq.1 fun t ht => (h ⟨t, x0⟩ ⟨ht, hx0⟩).1,
    PortRange.covers_of_sub hq.2 fun x hx => (h ⟨t0, x⟩ ⟨ht0, hx⟩).2⟩

theorem covers_iff {p q : EndpointPattern} (hq : q.WF) :
    p.Covers q ↔ ∀ t, q.Matches t → p.Matches t :=
  ⟨fun h _ ht => h.sound ht, covers_of_sub hq⟩

end EndpointPattern

/-! ## `Range` 全体 -/

namespace Range

/-- 外側 r が内側 s を覆う（引数は外側が先）。Top は全ての範囲を覆う。非 Top は同じ種類の範囲だけを、
その種類のパターンの被覆で覆い、Top を覆わない。 -/
def Covers : Range → Range → Prop
  | .top, _ => True
  | .path p, .path q => p.Covers q
  | .host p, .host q => p.Covers q
  | .endpoint p, .endpoint q => p.Covers q
  | _, _ => False

/-- 被覆の判定。 -/
def covers? : Range → Range → Bool
  | .top, _ => true
  | .path p, .path q => p.covers? q
  | .host p, .host q => p.covers? q
  | .endpoint p, .endpoint q => p.covers? q
  | _, _ => false

theorem covers?_spec (r s : Range) : r.covers? s = true ↔ r.Covers s := by
  cases r <;> cases s <;>
    simp [covers?, Covers, PathPattern.covers?_spec, HostPattern.covers?_spec,
      EndpointPattern.covers?_spec]

instance (r s : Range) : Decidable (r.Covers s) := decidable_of_iff _ (covers?_spec r s)

/-- Top は全ての範囲を覆う。 -/
theorem top_covers (s : Range) : Range.top.Covers s := trivial

/-- 非 Top は Top を覆わない。 -/
theorem not_covers_top {r : Range} (hr : r ≠ .top) : ¬ r.Covers .top := by
  cases r with
  | top => exact absurd rfl hr
  | path _ | host _ | endpoint _ => exact id

theorem covers_top_iff (r : Range) : r.Covers .top ↔ r = .top :=
  ⟨fun h => Classical.byContradiction fun hr => not_covers_top hr h, by rintro rfl; trivial⟩

/-- 非 Top が覆う範囲は同じ種類の範囲である。 -/
theorem Covers.kind {r s : Range} (h : r.Covers s) (hr : r ≠ .top) : s.kind? = r.kind? := by
  cases r <;> cases s <;> first | exact absurd rfl hr | rfl | exact h.elim

/-- 健全性: 覆うなら、内側に所属する対象は外側に所属する（意味の包含 `s.Sub r`）。 -/
theorem Covers.sound {r s : Range} (h : r.Covers s) : s.Sub r := by
  intro t ht
  cases r <;> cases s <;> cases t <;> simp only [Covers, Mem] at h ht ⊢
  · exact PathPattern.Covers.sound h ht
  · exact HostPattern.Covers.sound h ht
  · exact EndpointPattern.Covers.sound h ht

/-- 健全性の種類に相対的な形: 覆うなら、どの種類 `k` についても、内側への種類 `k` の所属は外側への
種類 `k` の所属を与える。 -/
theorem Covers.sound_memK {r s : Range} (h : r.Covers s) {k : Kind} {t : Target} (ht : s.MemK k t) :
    r.MemK k t :=
  MemK.of_sub ht h.sound

theorem Covers.refl (r : Range) : r.Covers r := by
  cases r with
  | top => trivial
  | path p => exact PathPattern.Covers.refl p
  | host p => exact HostPattern.Covers.refl p
  | endpoint p => exact EndpointPattern.Covers.refl p

theorem Covers.trans {r s u : Range} (h₁ : r.Covers s) (h₂ : s.Covers u) : r.Covers u := by
  cases r <;> cases s <;> cases u <;> simp only [Covers] at h₁ h₂ ⊢
  · exact PathPattern.Covers.trans h₁ h₂
  · exact HostPattern.Covers.trans h₁ h₂
  · exact EndpointPattern.Covers.trans h₁ h₂

/-- 正規形の範囲どうしでは、相互の被覆は構造の等号を与える。一原子どうしの言明であり、効果の行（原子の
集合）の相互包含から等号を導くものではない（判断 5）。 -/
theorem Covers.antisymm {r s : Range} (hr : r.Canonical) (hs : s.Canonical)
    (h₁ : r.Covers s) (h₂ : s.Covers r) : r = s := by
  match r, s, hr, hs, h₁, h₂ with
  | .top, .top, _, _, _, _ => rfl
  | .path _, .path _, _, _, h₁, h₂ => exact congrArg Range.path (PathPattern.Covers.antisymm h₁ h₂)
  | .host _, .host _, hr, hs, h₁, h₂ => exact congrArg Range.host (HostPattern.Covers.antisymm hr hs h₁ h₂)
  | .endpoint _, .endpoint _, hr, hs, h₁, h₂ =>
    exact congrArg Range.endpoint (EndpointPattern.Covers.antisymm hr hs h₁ h₂)

/-- 整形式の範囲は空でない。 -/
theorem nonempty {r : Range} (h : r.WF) : ∃ t, r.Mem t := by
  cases r with
  | top => exact ⟨.path [], trivial⟩
  | path p => obtain ⟨w, hw⟩ := p.nonempty; exact ⟨.path w, hw⟩
  | host p => obtain ⟨t, ht⟩ := p.nonempty; exact ⟨.host t, ht⟩
  | endpoint p => obtain ⟨t, ht⟩ := EndpointPattern.nonempty h; exact ⟨.endpoint t, ht⟩

/-- 完全性: 内側が整形式なら、意味の包含は被覆を与える。内側が Top で外側が非 Top のときは、外側と種類の
違う対象が Top に所属するので、意味の上でも包含しない。種類の違う非 Top どうしは、内側が空でないので
包含しない。 -/
theorem covers_of_sub {r s : Range} (hs : s.WF) (h : s.Sub r) : r.Covers s := by
  match r, s, hs, h with
  | .top, _, _, _ => trivial
  | .path p, .path q, _, h => exact PathPattern.covers_of_sub fun w hw => h (.path w) hw
  | .host p, .host q, hs, h => exact HostPattern.covers_of_sub hs fun t ht => h (.host t) ht
  | .endpoint p, .endpoint q, hs, h => exact EndpointPattern.covers_of_sub hs fun t ht => h (.endpoint t) ht
  | .path _, .top, _, h => exact (show False from h (.host (.name [])) trivial).elim
  | .host _, .top, _, h => exact (show False from h (.path []) trivial).elim
  | .endpoint _, .top, _, h => exact (show False from h (.path []) trivial).elim
  | .path _, .host q, _, h =>
    obtain ⟨t, ht⟩ := q.nonempty; exact (show False from h (.host t) ht).elim
  | .path _, .endpoint q, hs, h =>
    obtain ⟨t, ht⟩ := EndpointPattern.nonempty hs; exact (show False from h (.endpoint t) ht).elim
  | .host _, .path q, _, h =>
    obtain ⟨w, hw⟩ := q.nonempty; exact (show False from h (.path w) hw).elim
  | .host _, .endpoint q, hs, h =>
    obtain ⟨t, ht⟩ := EndpointPattern.nonempty hs; exact (show False from h (.endpoint t) ht).elim
  | .endpoint _, .path q, _, h =>
    obtain ⟨w, hw⟩ := q.nonempty; exact (show False from h (.path w) hw).elim
  | .endpoint _, .host q, _, h =>
    obtain ⟨t, ht⟩ := q.nonempty; exact (show False from h (.host t) ht).elim

/-- 内側が整形式なら、被覆は意味の包含と同値である。 -/
theorem covers_iff {r s : Range} (hs : s.WF) : r.Covers s ↔ s.Sub r :=
  ⟨Covers.sound, covers_of_sub hs⟩

/-- 種類に相対的な所属の完全性: 内側が整形式で非 Top、かつ種類 `k` に合うなら、種類 `k` の所属の包含は
被覆と同値である。 -/
theorem covers_iff_memK {r s : Range} (hs : s.WF) (hne : s ≠ .top) {k : Kind} (hk : s.FitsKind k) :
    r.Covers s ↔ ∀ t, s.MemK k t → r.MemK k t := by
  refine ⟨fun h _ ht => h.sound_memK ht, fun h => covers_of_sub hs fun t ht => (h t ⟨?_, ht⟩).2⟩
  have hkind := kind_of_mem ht hne
  rcases hk with hk | hk
  · rw [hk] at hkind; cases hkind
  · rw [hk] at hkind; cases hkind; rfl

/-- 種類に相対的な所属では、内側が Top のときの完全性は成り立たない: `/**` は種類 `path` の全ての対象を
含むが、Top を覆わない（非 Top は Top を覆わない）。 -/
theorem tree_root_memK_not_covers_top :
    (∀ t, Range.top.MemK .path t → (Range.path (.tree [])).MemK .path t) ∧
      ¬ (Range.path (.tree [])).Covers .top := by
  refine ⟨fun t ht => ?_, id⟩
  obtain ⟨hk, _⟩ := ht
  cases t with
  | path w => exact ⟨rfl, w, by simp⟩
  | host _ => cases hk
  | endpoint _ => cases hk

/-- 和による被覆を判定しない（判断 5）: 同じホストのパターンで、ポートの区間 `0..9` の対象は `0..4` か `5..9`
の範囲に所属するが、どちらの一原子も `0..9` の範囲を覆わない。 -/
theorem endpoint_union_not_covers (h : HostPattern) :
    (∀ t, (Range.endpoint ⟨h, ⟨0, 9⟩⟩).Mem t →
        (Range.endpoint ⟨h, ⟨0, 4⟩⟩).Mem t ∨ (Range.endpoint ⟨h, ⟨5, 9⟩⟩).Mem t) ∧
      ¬ (Range.endpoint ⟨h, ⟨0, 4⟩⟩).Covers (.endpoint ⟨h, ⟨0, 9⟩⟩) ∧
      ¬ (Range.endpoint ⟨h, ⟨5, 9⟩⟩).Covers (.endpoint ⟨h, ⟨0, 9⟩⟩) := by
  obtain ⟨hu, h04, h59⟩ := PortRange.union_not_covers
  refine ⟨fun t ht => ?_, fun hc => h04 hc.2, fun hc => h59 hc.2⟩
  cases t with
  | endpoint e =>
    rcases hu e.port ht.2 with hp | hp
    · exact Or.inl ⟨ht.1, hp⟩
    · exact Or.inr ⟨ht.1, hp⟩
  | path _ => exact ht.elim
  | host _ => exact ht.elim

/-! ### 正規化と被覆（義務 6 のうち範囲の部分） -/

theorem covers_normalize_left (r s : Range) : r.normalize.Covers s ↔ r.Covers s := by
  cases r with
  | top => exact Iff.rfl
  | path p => exact Iff.rfl
  | host p =>
    cases s with
    | host q => exact HostPattern.covers_normalize_left p q
    | _ => exact Iff.rfl
  | endpoint e =>
    cases e with
    | mk h ps =>
      cases s with
      | endpoint f =>
        simp only [normalize, Covers, EndpointPattern.Covers, HostPattern.covers_normalize_left]
      | _ => exact Iff.rfl

theorem covers_normalize_right (r s : Range) : r.Covers s.normalize ↔ r.Covers s := by
  cases s with
  | top => exact Iff.rfl
  | path q => exact Iff.rfl
  | host q =>
    cases r with
    | host p => exact HostPattern.covers_normalize_right p q
    | _ => exact Iff.rfl
  | endpoint f =>
    cases f with
    | mk h ps =>
      cases r with
      | endpoint e =>
        simp only [normalize, Covers, EndpointPattern.Covers, HostPattern.covers_normalize_right]
      | _ => exact Iff.rfl

/-- 正規化の前後で被覆は変わらない（外側・内側の両方を正規化しても）。 -/
theorem covers_normalize_iff (r s : Range) : r.normalize.Covers s.normalize ↔ r.Covers s :=
  (covers_normalize_left r s.normalize).trans (covers_normalize_right r s)

/-- 正規形の範囲は正規化で変わらない。 -/
theorem normalize_of_canonical {r : Range} (h : r.Canonical) : r.normalize = r := by
  cases r with
  | top => rfl
  | path p => rfl
  | host p => exact congrArg Range.host (HostPattern.normalize_of_canonical h)
  | endpoint e =>
    cases e with
    | mk hp ps => exact congrArg (fun x => Range.endpoint ⟨x, ps⟩) (HostPattern.normalize_of_canonical h)

theorem normalize_idem (r : Range) : r.normalize.normalize = r.normalize := by
  cases r with
  | top => rfl
  | path p => rfl
  | host p => exact congrArg Range.host (HostPattern.normalize_idem p)
  | endpoint e =>
    cases e with
    | mk hp ps => exact congrArg (fun x => Range.endpoint ⟨x, ps⟩) (HostPattern.normalize_idem hp)

/-- 整形式の範囲を同じ正規形へ写すのは、相互に覆う範囲だけである。 -/
theorem normalize_eq_iff {r s : Range} (hr : r.WF) (hs : s.WF) :
    r.normalize = s.normalize ↔ r.Covers s ∧ s.Covers r := by
  constructor
  · intro heq
    refine ⟨(covers_normalize_iff r s).mp ?_, (covers_normalize_iff s r).mp ?_⟩
    · rw [heq]; exact Covers.refl _
    · rw [heq]; exact Covers.refl _
  · rintro ⟨h₁, h₂⟩
    exact Covers.antisymm (normalize_canonical hr) (normalize_canonical hs)
      ((covers_normalize_iff r s).mpr h₁) ((covers_normalize_iff s r).mpr h₂)

/-- 整形式の範囲を同じ正規形へ写すのは、所属が一致する範囲だけである。正規化は所属の違う範囲を一つに
しない（隣接する CIDR などを合併しない）。逆に、所属が一致する整形式の範囲は同じ正規形を持つ。 -/
theorem normalize_eq_iff_mem {r s : Range} (hr : r.WF) (hs : s.WF) :
    r.normalize = s.normalize ↔ ∀ t, r.Mem t ↔ s.Mem t := by
  rw [normalize_eq_iff hr hs, covers_iff hs, covers_iff hr]
  exact ⟨fun ⟨h₁, h₂⟩ t => ⟨h₂ t, h₁ t⟩, fun h => ⟨fun t => (h t).mpr, fun t => (h t).mp⟩⟩

/-- prefix の長さが族の幅と違う CIDR のホストの範囲は、正規化で変わらない（`/32`・`/128` 以外の CIDR は
完全一致にも、ほかの CIDR にもならない）。 -/
theorem normalize_host_cidr {c : CIDR} (hp : c.prefixLen ≠ c.family.width) :
    (Range.host (.ip (.cidr c))).normalize = .host (.ip (.cidr c)) :=
  congrArg (fun x => Range.host (.ip x)) (IPPattern.normalize_cidr_of_ne hp)

/-- エンドポイントの範囲でも同じである。 -/
theorem normalize_endpoint_cidr {c : CIDR} (hp : c.prefixLen ≠ c.family.width) (ps : PortRange) :
    (Range.endpoint ⟨.ip (.cidr c), ps⟩).normalize = .endpoint ⟨.ip (.cidr c), ps⟩ :=
  congrArg (fun x => Range.endpoint ⟨.ip x, ps⟩) (IPPattern.normalize_cidr_of_ne hp)

end Range

/-! ## 小さい具体例

`#guard` はコンパイルした判定を評価し、カーネルの展開に頼らない。
-/

private def lan24 : CIDR := CIDR.v4 0xC0A80100 24      -- 192.168.1.0/24
private def lan25a : CIDR := CIDR.v4 0xC0A80100 25     -- 192.168.1.0/25
private def lan25b : CIDR := CIDR.v4 0xC0A80180 25     -- 192.168.1.128/25
private def host10 : IPAddr := IPAddr.v4 0xC0A8010A    -- 192.168.1.10
private def ep (h : HostPattern) (lo hi : Port) : Range := .endpoint ⟨h, ⟨lo, hi⟩⟩

-- ポートの区間。
#guard (PortRange.mk 0 1023).covers? ⟨80, 443⟩
#guard !(PortRange.mk 80 80).covers? ⟨80, 81⟩
#guard (PortRange.mk 443 443).covers? ⟨443, 443⟩
-- 和による被覆を判定しない: `0..9` を `0..4` も `5..9` も覆わない。`0..9` は両方を覆う。
#guard !(PortRange.mk 0 4).covers? ⟨0, 9⟩ && !(PortRange.mk 5 9).covers? ⟨0, 9⟩
#guard (PortRange.mk 0 9).covers? ⟨0, 4⟩ && (PortRange.mk 0 9).covers? ⟨5, 9⟩
-- エンドポイントはホストとポートの両方で覆う。
#guard (ep (.ip (.cidr lan24)) 0 1023).covers? (ep (.ip (.exact host10)) 80 80)
#guard !(ep (.ip (.cidr lan24)) 80 80).covers? (ep (.ip (.exact host10)) 80 81)
#guard !(ep (.ip (.cidr lan25b)) 0 1023).covers? (ep (.ip (.exact host10)) 80 80)
#guard (ep (.name (.many ["example", "com"])) 443 443).covers? (ep (.name (.one ["example", "com"])) 443 443)
-- ホスト名と IP の組は覆わない。
#guard !(HostPattern.name (.many ["0", "168", "192"])).covers? (.ip (.exact host10))
#guard !(HostPattern.ip (.cidr (CIDR.v4 0 0))).covers? (.name (.exact ["localhost"]))
-- Top は全てを覆い、非 Top は Top と種類の違う範囲を覆わない。
#guard Range.top.covers? (.path (.tree ["data"])) && Range.top.covers? .top
#guard !(Range.path (.tree [])).covers? .top
#guard !(Range.path (.tree [])).covers? (.host (.name (.exact ["data"])))
#guard (Range.path (.tree ["data"])).covers? (.path (.exact ["data", "a"]))
-- 正規化: `/32` と完全一致は正規化の前は構造の上で別の範囲だが互いに覆い、正規化の後は同じ範囲になる。
#guard (Range.host (.ip (.cidr (CIDR.v4 0xC0A8010A 32)))) != .host (.ip (.exact host10))
#guard (Range.host (.ip (.cidr (CIDR.v4 0xC0A8010A 32)))).covers? (.host (.ip (.exact host10)))
#guard (Range.host (.ip (.exact host10))).covers? (.host (.ip (.cidr (CIDR.v4 0xC0A8010A 32))))
#guard (Range.host (.ip (.cidr (CIDR.v4 0xC0A8010A 32)))).normalize == .host (.ip (.exact host10))
-- 隣接する二つの `/25` は合併しない: 正規化で変わらず、`/24` は両方を覆うが、どちらの `/25` も `/24` を覆わない。
#guard (Range.host (.ip (.cidr lan25a))).normalize == .host (.ip (.cidr lan25a))
#guard (Range.host (.ip (.cidr lan25b))).normalize == .host (.ip (.cidr lan25b))
#guard (Range.host (.ip (.cidr lan24))).covers? (.host (.ip (.cidr lan25a)))
#guard (Range.host (.ip (.cidr lan24))).covers? (.host (.ip (.cidr lan25b)))
#guard !(Range.host (.ip (.cidr lan25a))).covers? (.host (.ip (.cidr lan24)))
#guard !(Range.host (.ip (.cidr lan25b))).covers? (.host (.ip (.cidr lan24)))
-- エンドポイントの正規化も、ホストの `/32` だけを揃える。
#guard (ep (.ip (.cidr (CIDR.v4 0xC0A8010A 32))) 80 80).normalize == ep (.ip (.exact host10)) 80 80
#guard (ep (.ip (.cidr lan24)) 80 80).normalize == ep (.ip (.cidr lan24)) 80 80

end Benitoite.Scope.Domain
