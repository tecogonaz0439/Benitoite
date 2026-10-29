import Std

/-!
# 範囲付きのエフェクトの対象の分類（採用定義）

範囲付きのエフェクトと範囲を添字に持つ標準値型が使う、閉じた範囲と対象の分類を定める。0.0.13 の L00 の
比較の後、設計者が採用した定義である（L00.08 の一括の問い、問 17）。格納方式は案 (i)（範囲を既存の構成子の
引数に置く）に決まったが、本ファイルは格納方式に依存しない独立の帰納型のままとし、`Std` だけを import する。
`Release` と、IP と CIDR へ一般化した `Checked.Scope` が本モジュールを import する（逆向きの import は循環に
なる）。

名前の扱い: `Range` は `Checked.Range`（区間）に同じ短い名前がある。`Checked.Scope` は独自の `HostPattern`・
`PathPattern` を持たず、本モジュールの型を使う。本モジュールの名前は名前空間 `Benitoite.Scope.Domain` に
固定し、`Checked` と `Interval` のモジュールでは `open Benitoite.Scope.Domain` をせず `Scope.Domain.Range` などと修飾して書く。

対象はすべて解析済みの値である。パスとホスト名は要素の列（`Word`）、IP アドレスはアドレス族と
固定幅の数値、ポートは `Fin 65536` で表す。文字列からの解析（パスの分割、ホスト名の小文字化、
IPv4・IPv6・CIDR の字句、URL からの host の取り出し、整数からポートへの変換の前の範囲の確かめ）は
形式化の外側に置き、解析器の正しさは仮定も証明もしない（`Checked.Scope` と同じ境界）。

設計者の決定（DET-01 の領域の部分）を次の形で反映する。

- 旧 Scope の対象と新しい範囲は同じ領域を使う。ホストの対象はホスト名か IP アドレスであり、
  ホストのパターンはホスト名のパターンか IP のパターン（完全一致・CIDR）である。
- IPv4 を射影した IPv6 アドレス（`::ffff:192.0.2.1`）は IPv6 の 128 ビットの値であり、IPv4 の値と
  同じものとみなさない。アドレス族を値の一部に持つので、族の違う値は所属しない。
- `/32`・`/128` の CIDR は `IPPattern.normalize` で完全一致へ揃える。正規化の後は同じ原子である。

残る字句の細則（DET-01）は language-rules A2 の案のとおりであり、zone ID と IPvFuture は対象外として構成子を
置かない。それ以外の細則は形式化の外側の解析器が決め、本ファイルの帰納型と所属を変えない。被覆の判定と
その健全性・推移は L10 で定義し証明する。Top の所属は名前の種類に相対的である（`Range.MemK`）。
-/

namespace Benitoite.Scope.Domain

/-- 解析済みの要素の列。パスは根からの要素の順、ホスト名は通常の順（左のラベルが先頭）で並べる。 -/
abbrev Word := List String

/-! ## パス -/

/-- パスのパターン。`exact` は完全一致、`tree` は末尾 `/**` の木（幹自身と任意の段の子を含む）。
根 `/` は空の列であり、`tree []` は `/**` に当たる。 -/
inductive PathPattern where
  | exact (stem : Word)
  | tree (stem : Word)
  deriving DecidableEq, Repr

namespace PathPattern

def Matches : PathPattern → Word → Prop
  | .exact s, p => p = s
  | .tree s, p => ∃ rest, p = s ++ rest

def matches? : PathPattern → Word → Bool
  | .exact s, p => decide (p = s)
  | .tree s, p => s.isPrefixOf p

theorem matches?_spec (pat : PathPattern) (p : Word) : pat.matches? p = true ↔ pat.Matches p := by
  cases pat with
  | exact s => simp [matches?, Matches]
  | tree s =>
    simp only [matches?, List.isPrefixOf_iff_prefix, List.IsPrefix, Matches]
    exact exists_congr fun _ => eq_comm

instance (pat : PathPattern) (p : Word) : Decidable (pat.Matches p) :=
  decidable_of_iff _ (matches?_spec pat p)

end PathPattern

/-! ## ホスト名 -/

/-- ホスト名のパターン。`exact` は完全一致、`one` は `*.` のちょうど一段、`many` は `**.` の一段以上。
`one` と `many` は幹自身を含まない。 -/
inductive NamePattern where
  | exact (stem : Word)
  | one (stem : Word)
  | many (stem : Word)
  deriving DecidableEq, Repr

namespace NamePattern

/-- 通常の順のラベル列での所属。幹は列の末尾に来る。 -/
def Matches : NamePattern → Word → Prop
  | .exact s, h => h = s
  | .one s, h => ∃ x, h = x :: s
  | .many s, h => ∃ xs, xs ≠ [] ∧ h = xs ++ s

/-- 逆順（右のラベルが先頭）のラベル列での所属。幹は列の先頭に来る。処理系の実装が右から
ラベルを比べることとの対応に使う。 -/
def MatchesRev : NamePattern → Word → Prop
  | .exact s, r => r = s.reverse
  | .one s, r => ∃ x, r = s.reverse ++ [x]
  | .many s, r => ∃ xs, xs ≠ [] ∧ r = s.reverse ++ xs

def matches? : NamePattern → Word → Bool
  | .exact s, h => decide (h = s)
  | .one _, [] => false
  | .one s, _ :: tail => decide (tail = s)
  | .many s, h => s.isSuffixOf h && decide (s.length < h.length)

theorem matches?_spec (pat : NamePattern) (h : Word) : pat.matches? h = true ↔ pat.Matches h := by
  cases pat with
  | exact s => simp [matches?, Matches]
  | one s => cases h <;> simp [matches?, Matches]
  | many s =>
    simp only [matches?, Bool.and_eq_true, List.isSuffixOf_iff_suffix,
      decide_eq_true_eq, List.IsSuffix, Matches]
    constructor
    · rintro ⟨⟨xs, hx⟩, hl⟩
      refine ⟨xs, ?_, hx.symm⟩
      intro he; subst xs; simp_all
    · rintro ⟨xs, hx, rfl⟩
      refine ⟨⟨xs, rfl⟩, ?_⟩
      have : 0 < xs.length := List.length_pos_iff.mpr hx
      simp only [List.length_append]; omega

instance (pat : NamePattern) (h : Word) : Decidable (pat.Matches h) :=
  decidable_of_iff _ (matches?_spec pat h)

/-- 通常の順と逆順の所属の対応。 -/
theorem matches_iff_rev (pat : NamePattern) (h : Word) : pat.Matches h ↔ pat.MatchesRev h.reverse := by
  cases pat with
  | exact s =>
    simp only [Matches, MatchesRev]
    exact ⟨fun e => e ▸ rfl, fun e => List.reverse_inj.mp e⟩
  | one s =>
    simp only [Matches, MatchesRev]
    constructor
    · rintro ⟨x, rfl⟩; exact ⟨x, by simp⟩
    · rintro ⟨x, hx⟩
      refine ⟨x, ?_⟩
      have := congrArg List.reverse hx
      simpa using this
  | many s =>
    simp only [Matches, MatchesRev]
    constructor
    · rintro ⟨xs, hne, rfl⟩
      exact ⟨xs.reverse, by simpa using hne, by simp⟩
    · rintro ⟨xs, hne, hx⟩
      refine ⟨xs.reverse, by simpa using hne, ?_⟩
      have := congrArg List.reverse hx
      simpa using this

end NamePattern

/-! ## IP アドレスと CIDR -/

/-- アドレス族。IPv4 を射影した IPv6 アドレスも `v6` の値である。 -/
inductive Family where
  | v4
  | v6
  deriving DecidableEq, Repr

/-- アドレス族ごとのビット幅。 -/
def Family.width : Family → Nat
  | .v4 => 32
  | .v6 => 128

/-- 解析済みの IP アドレス。値はアドレス族の幅に収まる数値であり、`2 ^ width` 自身は値に持たない。 -/
structure IPAddr where
  family : Family
  bits : Fin (2 ^ family.width)
  deriving DecidableEq, Repr

theorem IPAddr.ext' {a b : IPAddr} (hf : a.family = b.family) (hv : a.bits.val = b.bits.val) :
    a = b := by
  cases a with
  | mk fa va =>
    cases b with
    | mk fb vb =>
      simp only at hf hv
      subst hf
      exact congrArg (IPAddr.mk fa) (Fin.ext hv)

/-- CIDR の条件。`network` はネットワークの数値、`prefixLen` は prefix の長さ。 -/
structure CIDR where
  family : Family
  network : Fin (2 ^ family.width)
  prefixLen : Nat
  deriving DecidableEq, Repr

namespace CIDR

/-- ホスト部のビット数 `width - prefixLen`。 -/
def hostBits (c : CIDR) : Nat := c.family.width - c.prefixLen

/-- 区間の大きさ `2 ^ hostBits`。`/0` の大きさ `2 ^ width` は値に格納せず、ここで Nat として求める。 -/
def blockSize (c : CIDR) : Nat := 2 ^ c.hostBits

/-- 区間の下端。 -/
def lo (c : CIDR) : Nat := c.network.val

/-- 区間の上端 `network + 2 ^ hostBits - 1`（Nat の非負の演算）。 -/
def hi (c : CIDR) : Nat := c.network.val + c.blockSize - 1

/-- CIDR の整形式性。prefix の長さが幅を超えず、ホスト部のビットが全て 0 である。 -/
def WF (c : CIDR) : Prop := c.prefixLen ≤ c.family.width ∧ c.network.val % c.blockSize = 0

instance (c : CIDR) : Decidable c.WF := by unfold WF; infer_instance

/-- 区間による所属。アドレス族が同じで、区間 `[lo, hi]` に入る。 -/
def Mem (c : CIDR) (a : IPAddr) : Prop := a.family = c.family ∧ c.lo ≤ a.bits.val ∧ a.bits.val ≤ c.hi

instance (c : CIDR) (a : IPAddr) : Decidable (c.Mem a) := by unfold Mem; infer_instance

/-- prefix のビットの一致による所属。区間による所属 `Mem` との一致は L10 の義務であり、ここでは証明しない。 -/
def PrefixMem (c : CIDR) (a : IPAddr) : Prop :=
  a.family = c.family ∧ a.bits.val / c.blockSize = c.network.val / c.blockSize

private theorem add_le_of_dvd {d a b : Nat} (ha : d ∣ a) (hb : d ∣ b) (h : a < b) : a + d ≤ b := by
  obtain ⟨x, rfl⟩ := ha
  obtain ⟨y, rfl⟩ := hb
  have hd : 0 < d := Nat.pos_of_ne_zero (by rintro rfl; simp at h)
  have hxy : x < y := Nat.lt_of_mul_lt_mul_left h
  have : d * (x + 1) ≤ d * y := Nat.mul_le_mul_left d hxy
  simpa [Nat.mul_add] using this

/-- 整形式の CIDR の上端は幅に収まる。上端を `Fin` へ包む前に示す条件である。 -/
theorem hi_lt {c : CIDR} (h : c.WF) : c.hi < 2 ^ c.family.width := by
  obtain ⟨hp, hz⟩ := h
  have hpos : 0 < c.blockSize := Nat.pow_pos (by decide)
  have hdiv : c.blockSize ∣ 2 ^ c.family.width := by
    unfold blockSize hostBits
    exact Nat.pow_dvd_pow 2 (Nat.sub_le _ _)
  have hle := add_le_of_dvd (Nat.dvd_of_mod_eq_zero hz) hdiv c.network.isLt
  unfold hi
  omega

/-- 整形式の CIDR の上端を固定幅の値として得る。 -/
def hiFin (c : CIDR) (h : c.WF) : Fin (2 ^ c.family.width) := ⟨c.hi, hi_lt h⟩

/-- 最大長の prefix（`/32`・`/128`）の区間は一点である。 -/
theorem mem_of_prefix_eq_width {c : CIDR} (hp : c.prefixLen = c.family.width) (a : IPAddr) :
    c.Mem a ↔ a = ⟨c.family, c.network⟩ := by
  have hb : c.blockSize = 1 := by simp [blockSize, hostBits, hp]
  simp only [Mem, lo, hi, hb, Nat.add_sub_cancel]
  constructor
  · rintro ⟨hf, h1, h2⟩
    exact IPAddr.ext' hf (by simp only; omega)
  · rintro rfl
    exact ⟨rfl, Nat.le_refl _, Nat.le_refl _⟩

end CIDR

/-- IP のパターン。完全一致と CIDR。 -/
inductive IPPattern where
  | exact (a : IPAddr)
  | cidr (c : CIDR)
  deriving DecidableEq, Repr

namespace IPPattern

def Matches : IPPattern → IPAddr → Prop
  | .exact a, b => b = a
  | .cidr c, b => c.Mem b

instance (p : IPPattern) (a : IPAddr) : Decidable (p.Matches a) := by
  cases p <;> unfold Matches <;> infer_instance

/-- 最大長の prefix の CIDR を完全一致へ揃える（設計者の決定、DET-01 の領域の部分）。
隣接する CIDR の合併や、広い原子に含まれる狭い原子の除去は行わない。 -/
def normalize : IPPattern → IPPattern
  | .exact a => .exact a
  | .cidr c => if c.prefixLen = c.family.width then .exact ⟨c.family, c.network⟩ else .cidr c

/-- 正規形。CIDR の prefix は最大長より短い。 -/
def Canonical : IPPattern → Prop
  | .exact _ => True
  | .cidr c => c.prefixLen < c.family.width

instance (p : IPPattern) : Decidable p.Canonical := by
  cases p <;> unfold Canonical <;> infer_instance

def WF : IPPattern → Prop
  | .exact _ => True
  | .cidr c => c.WF

instance (p : IPPattern) : Decidable p.WF := by
  cases p <;> unfold WF <;> infer_instance

theorem normalize_cidr_of_eq {c : CIDR} (hp : c.prefixLen = c.family.width) :
    (IPPattern.cidr c).normalize = .exact ⟨c.family, c.network⟩ := by
  simp [normalize, hp]

theorem normalize_cidr_of_ne {c : CIDR} (hp : c.prefixLen ≠ c.family.width) :
    (IPPattern.cidr c).normalize = .cidr c := by
  simp [normalize, hp]

theorem normalize_matches (p : IPPattern) (a : IPAddr) : p.normalize.Matches a ↔ p.Matches a := by
  cases p with
  | exact b => rfl
  | cidr c =>
    by_cases hp : c.prefixLen = c.family.width
    · rw [normalize_cidr_of_eq hp]
      exact (CIDR.mem_of_prefix_eq_width hp a).symm
    · rw [normalize_cidr_of_ne hp]

theorem normalize_canonical {p : IPPattern} (h : p.WF) : p.normalize.Canonical := by
  cases p with
  | exact b => trivial
  | cidr c =>
    by_cases hp : c.prefixLen = c.family.width
    · rw [normalize_cidr_of_eq hp]; trivial
    · rw [normalize_cidr_of_ne hp]; exact Nat.lt_of_le_of_ne h.1 hp

theorem normalize_wf {p : IPPattern} (h : p.WF) : p.normalize.WF := by
  cases p with
  | exact b => trivial
  | cidr c =>
    by_cases hp : c.prefixLen = c.family.width
    · rw [normalize_cidr_of_eq hp]; trivial
    · rw [normalize_cidr_of_ne hp]; exact h

theorem normalize_of_canonical {p : IPPattern} (h : p.Canonical) : p.normalize = p := by
  cases p with
  | exact b => rfl
  | cidr c => exact normalize_cidr_of_ne (Nat.ne_of_lt h)

theorem normalize_idem (p : IPPattern) : p.normalize.normalize = p.normalize := by
  cases p with
  | exact b => rfl
  | cidr c =>
    by_cases hp : c.prefixLen = c.family.width
    · rw [normalize_cidr_of_eq hp]; rfl
    · rw [normalize_cidr_of_ne hp, normalize_cidr_of_ne hp]

/-- 最大長の CIDR と同じアドレスの完全一致は、正規化の後に同じ原子になる。 -/
theorem normalize_cidr_width (f : Family) (n : Fin (2 ^ f.width)) :
    (IPPattern.cidr ⟨f, n, f.width⟩).normalize = (IPPattern.exact ⟨f, n⟩).normalize := by
  simp [normalize]

end IPPattern

/-! ## ホスト -/

/-- ホストの対象。ホスト名か IP アドレスであり、互いに変換しない（DNS の解決を含めない）。 -/
inductive HostTarget where
  | name (w : Word)
  | ip (a : IPAddr)
  deriving DecidableEq, Repr

/-- ホストのパターン。ホスト名のパターンは IP の対象を含まず、IP のパターンはホスト名の対象を含まない。 -/
inductive HostPattern where
  | name (p : NamePattern)
  | ip (p : IPPattern)
  deriving DecidableEq, Repr

namespace HostPattern

def Matches : HostPattern → HostTarget → Prop
  | .name p, .name w => p.Matches w
  | .ip p, .ip a => p.Matches a
  | _, _ => False

instance (p : HostPattern) (t : HostTarget) : Decidable (p.Matches t) := by
  cases p <;> cases t <;> unfold Matches <;> infer_instance

def normalize : HostPattern → HostPattern
  | .name p => .name p
  | .ip p => .ip p.normalize

theorem normalize_matches (p : HostPattern) (t : HostTarget) : p.normalize.Matches t ↔ p.Matches t := by
  cases p <;> cases t <;> simp only [normalize, Matches]
  exact IPPattern.normalize_matches _ _

end HostPattern

/-! ## ポートとエンドポイント -/

/-- 解析済みのポート。上限 65535 を型で表す。 -/
abbrev Port := Fin 65536

/-- 言語の整数からポートへの変換。範囲外は `none`（`Checked.Scope.ValidPort` と同じ条件）。 -/
def Port.ofInt? (i : Int) : Option Port :=
  if h : 0 ≤ i ∧ i ≤ 65535 then some ⟨i.toNat, by omega⟩ else none

theorem Port.ofInt?_isSome_iff (i : Int) : (Port.ofInt? i).isSome ↔ 0 ≤ i ∧ i ≤ 65535 := by
  unfold Port.ofInt?
  split <;> simp_all

theorem Port.ofInt?_val {i : Int} {p : Port} (h : Port.ofInt? i = some p) : (p.val : Int) = i := by
  unfold Port.ofInt? at h
  split at h
  · rename_i hb
    cases h
    simp only
    omega
  · cases h

/-- ポートの閉区間。 -/
structure PortRange where
  lo : Port
  hi : Port
  deriving DecidableEq, Repr

def PortRange.Mem (r : PortRange) (p : Port) : Prop := r.lo ≤ p ∧ p ≤ r.hi

instance (r : PortRange) (p : Port) : Decidable (r.Mem p) := by unfold PortRange.Mem; infer_instance

/-- ポートの区間の整形式性 `lo ≤ hi`。`0 ≤ lo` と `hi ≤ 65535` は型が表す。 -/
def PortRange.WF (r : PortRange) : Prop := r.lo ≤ r.hi

instance (r : PortRange) : Decidable r.WF := by unfold PortRange.WF; infer_instance

/-- エンドポイントの対象。ホストとポートの組。 -/
structure Endpoint where
  host : HostTarget
  port : Port
  deriving DecidableEq, Repr

/-- エンドポイントのパターン。ホストのパターンとポートの区間の積。 -/
structure EndpointPattern where
  host : HostPattern
  ports : PortRange
  deriving DecidableEq, Repr

def EndpointPattern.Matches (e : EndpointPattern) (t : Endpoint) : Prop :=
  e.host.Matches t.host ∧ e.ports.Mem t.port

instance (e : EndpointPattern) (t : Endpoint) : Decidable (e.Matches t) := by
  unfold EndpointPattern.Matches; infer_instance

/-! ## 対象と範囲 -/

/-- 対象の種類。エフェクトの名前と値型ごとに一つの種類が決まる（名前と種類の対応は署名の表が持つ）。 -/
inductive Kind where
  | path
  | host
  | endpoint
  deriving DecidableEq, Repr

/-- 操作の対象。 -/
inductive Target where
  | path (w : Word)
  | host (h : HostTarget)
  | endpoint (e : Endpoint)
  deriving DecidableEq, Repr

def Target.kind : Target → Kind
  | .path _ => .path
  | .host _ => .host
  | .endpoint _ => .endpoint

/-- 閉じた範囲。`top` は名前だけの原子（旧の原子）に当たり、その種類の全対象を覆う上限である。 -/
inductive Range where
  | top
  | path (p : PathPattern)
  | host (p : HostPattern)
  | endpoint (p : EndpointPattern)
  deriving DecidableEq, Repr

namespace Range

/-- 範囲が決める種類。`top` は種類を持たず、名前の種類に従う。 -/
def kind? : Range → Option Kind
  | .top => none
  | .path _ => some .path
  | .host _ => some .host
  | .endpoint _ => some .endpoint

/-- 範囲が種類 `k` の名前に置けること。`top` はどの種類にも置ける。 -/
def FitsKind (r : Range) (k : Kind) : Prop := r.kind? = none ∨ r.kind? = some k

instance (r : Range) (k : Kind) : Decidable (r.FitsKind k) := by unfold FitsKind; infer_instance

/-- 範囲への所属。`top` は全対象を含む。種類の違う対象は非 `top` の範囲に所属しない。 -/
def Mem : Range → Target → Prop
  | .top, _ => True
  | .path p, .path w => p.Matches w
  | .host p, .host h => p.Matches h
  | .endpoint p, .endpoint e => p.Matches e
  | _, _ => False

instance (r : Range) (t : Target) : Decidable (r.Mem t) := by
  cases r <;> cases t <;> unfold Mem <;> infer_instance

/-- 正規化。IP の最大長の CIDR を完全一致へ揃えることだけを行う。 -/
def normalize : Range → Range
  | .top => .top
  | .path p => .path p
  | .host p => .host p.normalize
  | .endpoint ⟨h, ps⟩ => .endpoint ⟨h.normalize, ps⟩

theorem normalize_mem (r : Range) (t : Target) : r.normalize.Mem t ↔ r.Mem t := by
  cases r with
  | top => rfl
  | path p => rfl
  | host p =>
    cases t <;> simp only [normalize, Mem]
    exact HostPattern.normalize_matches _ _
  | endpoint e =>
    cases e
    cases t <;> simp only [normalize, Mem, EndpointPattern.Matches]
    rw [HostPattern.normalize_matches]

theorem normalize_kind (r : Range) : r.normalize.kind? = r.kind? := by
  cases r with
  | endpoint e => cases e; rfl
  | _ => rfl

/-! ### 旧 Top の小補題 -/

@[simp] theorem top_mem (t : Target) : Range.top.Mem t := trivial

theorem top_fitsKind (k : Kind) : Range.top.FitsKind k := Or.inl rfl

@[simp] theorem top_normalize : Range.top.normalize = .top := rfl

theorem eq_top_of_kind_none {r : Range} (h : r.kind? = none) : r = .top := by
  cases r <;> simp_all [kind?]

/-! ### 意味の包含と種類に相対的な所属 -/

/-- 範囲の意味の包含。静的な判定（被覆）とその健全性は L10 で定める。 -/
def Sub (r s : Range) : Prop := ∀ t, r.Mem t → s.Mem t

theorem Sub.refl (r : Range) : r.Sub r := fun _ h => h

theorem Sub.trans {r s u : Range} (h₁ : r.Sub s) (h₂ : s.Sub u) : r.Sub u := fun t h => h₂ t (h₁ t h)

theorem sub_top (r : Range) : r.Sub .top := fun _ _ => trivial

/-- 種類 k の名前のもとでの所属。Top は種類 k の全対象を覆い、他の種類の対象を覆わない（判断 5 の
「Top は同じ種類の全対象を覆う」）。非 Top の範囲は種類の一致と所属を要する。 -/
def MemK (k : Kind) (r : Range) (t : Target) : Prop := t.kind = k ∧ r.Mem t

instance (k : Kind) (r : Range) (t : Target) : Decidable (r.MemK k t) := by unfold MemK; infer_instance

theorem memK_top_iff (k : Kind) (t : Target) : Range.top.MemK k t ↔ t.kind = k :=
  ⟨fun h => h.1, fun h => ⟨h, trivial⟩⟩

/-- 非 Top の範囲への所属は、範囲の種類と対象の種類の一致を含む。 -/
theorem kind_of_mem {r : Range} {t : Target} (h : r.Mem t) (hne : r ≠ .top) : r.kind? = some t.kind := by
  cases r <;> cases t <;> simp_all [Mem, kind?, Target.kind]

/-- 種類 k に置ける非 Top の範囲では、種類に相対的な所属は所属と同じである。 -/
theorem memK_iff_mem {r : Range} {k : Kind} (hfit : r.FitsKind k) (hne : r ≠ .top) (t : Target) :
    r.MemK k t ↔ r.Mem t := by
  refine ⟨fun h => h.2, fun h => ⟨?_, h⟩⟩
  have hk := kind_of_mem h hne
  rcases hfit with hn | hs
  · exact absurd (eq_top_of_kind_none hn) hne
  · rw [hs] at hk; exact (Option.some.inj hk).symm

theorem MemK.of_sub {r s : Range} {k : Kind} {t : Target} (h : r.MemK k t) (hs : r.Sub s) : s.MemK k t :=
  ⟨h.1, hs t h.2⟩

/-- 範囲の列が、範囲の変数の種類の列に置ける（長さの一致を含む）。 -/
def FitsKinds : List Range → List Kind → Prop
  | [], [] => True
  | r :: rs, k :: ks => r.FitsKind k ∧ FitsKinds rs ks
  | _, _ => False

instance instDecidableFitsKinds : ∀ (rs : List Range) (ks : List Kind), Decidable (FitsKinds rs ks)
  | [], [] => inferInstanceAs (Decidable True)
  | [], _ :: _ => inferInstanceAs (Decidable False)
  | _ :: _, [] => inferInstanceAs (Decidable False)
  | r :: rs, k :: ks =>
    have := instDecidableFitsKinds rs ks
    inferInstanceAs (Decidable (r.FitsKind k ∧ FitsKinds rs ks))

theorem FitsKinds.length {rs : List Range} {ks : List Kind} (h : FitsKinds rs ks) : rs.length = ks.length := by
  induction rs generalizing ks with
  | nil => cases ks <;> simp_all [FitsKinds]
  | cons r rs ih =>
    cases ks with
    | nil => simp [FitsKinds] at h
    | cons k ks => simp only [FitsKinds] at h; simp [ih h.2]

/-- 範囲の列の i 番目の範囲は、種類の列の i 番目の種類に置ける。 -/
theorem FitsKinds.getElem? {rs : List Range} {ks : List Kind} (h : FitsKinds rs ks) {i : Nat} {r : Range}
    {k : Kind} (hr : rs[i]? = some r) (hk : ks[i]? = some k) : r.FitsKind k := by
  induction rs generalizing ks i with
  | nil => simp at hr
  | cons r' rs ih =>
    cases ks with
    | nil => simp at hk
    | cons k' ks =>
      simp only [FitsKinds] at h
      cases i with
      | zero => simp at hr hk; subst hr; subst hk; exact h.1
      | succ i => exact ih h.2 (by simpa using hr) (by simpa using hk)

theorem fitsKinds_nil : FitsKinds [] [] := trivial

/-! ### 一つの非 Top（パスの完全一致）の小補題 -/

/-- パスの完全一致の範囲の構築。 -/
def pathExact (w : Word) : Range := .path (.exact w)

theorem mem_pathExact_iff (w : Word) (t : Target) : (pathExact w).Mem t ↔ t = .path w := by
  cases t <;> simp [pathExact, Mem, PathPattern.Matches]

theorem pathExact_fitsKind_iff (w : Word) (k : Kind) : (pathExact w).FitsKind k ↔ k = .path := by
  simp only [FitsKind, pathExact, kind?]
  constructor
  · rintro (h | h)
    · cases h
    · cases h; rfl
  · rintro rfl; exact Or.inr rfl

theorem pathExact_ne_top (w : Word) : pathExact w ≠ .top := by
  simp [pathExact]

@[simp] theorem pathExact_normalize (w : Word) : (pathExact w).normalize = pathExact w := rfl

end Range

/-! ## 整形式性の条件

範囲の整形式性と正規形は型の整形式性に入れず、具体化の許容（`Scope.Signature.RangeAdmissible`）と
解析器の出力の性質として扱う（L00.08 の一括の問い、問 4）。所属の定義（`Mem`）は整形式性を前提にしない。
ホスト名とパスの条件は旧の `Checked.Scope` の条件を写したものである（新しい字句の規則を加えない）。
`Checked.Scope` は同じ述語を定義し直さず、本節の述語を使う（問 17）。
-/

/-- ホスト名のラベルの文字。正規化（ASCII 小文字化）の後だけを扱う。 -/
def lowerAlphaNumeric (c : Char) : Bool :=
  decide (('a' ≤ c ∧ c ≤ 'z') ∨ ('0' ≤ c ∧ c ≤ '9'))

def NameLabelWF (s : String) : Prop :=
  s ≠ "" ∧ s.toList.head? ≠ some '-' ∧ s.toList.getLast? ≠ some '-' ∧
    s.toList.all (fun c => lowerAlphaNumeric c || c == '-') = true

instance (s : String) : Decidable (NameLabelWF s) := by unfold NameLabelWF; infer_instance

/-- 四つの全数字のラベル。ホスト名に含めず、IP の解析へ渡す形である。 -/
def FourDigitLabels (w : Word) : Prop :=
  w.length = 4 ∧ w.all (fun s => !s.isEmpty && s.toList.all Char.isDigit) = true

instance (w : Word) : Decidable (FourDigitLabels w) := by unfold FourDigitLabels; infer_instance

/-- ホスト名（対象とパターンの幹）の整形式性。 -/
def NameWordWF (w : Word) : Prop := w ≠ [] ∧ (∀ s ∈ w, NameLabelWF s) ∧ ¬ FourDigitLabels w

instance (w : Word) : Decidable (NameWordWF w) := by unfold NameWordWF; infer_instance

def NamePattern.WF : NamePattern → Prop
  | .exact s | .one s | .many s => NameWordWF s

instance (p : NamePattern) : Decidable p.WF := by cases p <;> unfold NamePattern.WF <;> infer_instance

/-- パスの要素。空・`.`・`..`・区切り・逆斜線・NUL を含まない。根は空の列で表す。 -/
def PathPartWF (s : String) : Prop :=
  s ≠ "" ∧ s ≠ "." ∧ s ≠ ".." ∧
    s.toList.all (fun c => c != '/' && c != '\\' && c != '\x00') = true

instance (s : String) : Decidable (PathPartWF s) := by unfold PathPartWF; infer_instance

/-- 正規のパス（対象）。対象の要素には `*` を書ける。 -/
def PathWordWF (w : Word) : Prop := ∀ s ∈ w, PathPartWF s

instance (w : Word) : Decidable (PathWordWF w) := by unfold PathWordWF; infer_instance

/-- パスのパターン。幹は正規のパスであり、要素に `*` を含まない。 -/
def PathPattern.WF : PathPattern → Prop
  | .exact s | .tree s => PathWordWF s ∧ ∀ part ∈ s, part.toList.all (fun c => c != '*') = true

instance (p : PathPattern) : Decidable p.WF := by cases p <;> unfold PathPattern.WF <;> infer_instance

def HostTarget.WF : HostTarget → Prop
  | .name w => NameWordWF w
  | .ip _ => True

instance (t : HostTarget) : Decidable t.WF := by cases t <;> unfold HostTarget.WF <;> infer_instance

def HostPattern.WF : HostPattern → Prop
  | .name p => p.WF
  | .ip p => p.WF

instance (p : HostPattern) : Decidable p.WF := by cases p <;> unfold HostPattern.WF <;> infer_instance

def HostPattern.Canonical : HostPattern → Prop
  | .name _ => True
  | .ip p => p.Canonical

instance (p : HostPattern) : Decidable p.Canonical := by
  cases p <;> unfold HostPattern.Canonical <;> infer_instance

def EndpointPattern.WF (e : EndpointPattern) : Prop := e.host.WF ∧ e.ports.WF

instance (e : EndpointPattern) : Decidable e.WF := by unfold EndpointPattern.WF; infer_instance

def Target.WF : Target → Prop
  | .path w => PathWordWF w
  | .host h => h.WF
  | .endpoint e => e.host.WF

instance (t : Target) : Decidable t.WF := by cases t <;> unfold Target.WF <;> infer_instance

/-- 範囲の整形式性。`top` は常に整形式である。 -/
def Range.WF : Range → Prop
  | .top => True
  | .path p => p.WF
  | .host p => p.WF
  | .endpoint e => e.WF

instance (r : Range) : Decidable r.WF := by cases r <;> unfold Range.WF <;> infer_instance

/-- 範囲の正規形。IP の CIDR の prefix は最大長より短い。 -/
def Range.Canonical : Range → Prop
  | .top | .path _ => True
  | .host p => p.Canonical
  | .endpoint e => e.host.Canonical

instance (r : Range) : Decidable r.Canonical := by cases r <;> unfold Range.Canonical <;> infer_instance

theorem HostPattern.normalize_wf {p : HostPattern} (h : p.WF) : p.normalize.WF := by
  cases p with
  | name q => exact h
  | ip q => exact IPPattern.normalize_wf h

theorem HostPattern.normalize_canonical {p : HostPattern} (h : p.WF) : p.normalize.Canonical := by
  cases p with
  | name q => trivial
  | ip q => exact IPPattern.normalize_canonical h

theorem Range.normalize_wf {r : Range} (h : r.WF) : r.normalize.WF := by
  cases r with
  | top => trivial
  | path p => exact h
  | host p => exact HostPattern.normalize_wf h
  | endpoint e => cases e; exact ⟨HostPattern.normalize_wf h.1, h.2⟩

theorem Range.normalize_canonical {r : Range} (h : r.WF) : r.normalize.Canonical := by
  cases r with
  | top => trivial
  | path p => trivial
  | host p => exact HostPattern.normalize_canonical h
  | endpoint e => cases e; exact HostPattern.normalize_canonical h.1

@[simp] theorem Range.top_wf : Range.top.WF := trivial

theorem Range.pathExact_wf_iff (w : Word) :
    (Range.pathExact w).WF ↔ PathWordWF w ∧ ∀ part ∈ w, part.toList.all (fun c => c != '*') = true :=
  Iff.rfl

/-! ## 小さい具体例

具体の確かめは `#guard`（コンパイルした判定の評価）で行い、カーネルの展開に頼らない。
-/

/-- 例に使う IPv4 アドレスの構築（`n < 2 ^ 32` を確かめる）。 -/
def IPAddr.v4 (n : Nat) (h : n < 2 ^ 32 := by decide) : IPAddr := ⟨.v4, ⟨n, h⟩⟩

/-- 例に使う IPv6 アドレスの構築（`n < 2 ^ 128` を確かめる）。 -/
def IPAddr.v6 (n : Nat) (h : n < 2 ^ 128 := by decide) : IPAddr := ⟨.v6, ⟨n, h⟩⟩

/-- 例に使う CIDR の構築。 -/
def CIDR.v4 (n p : Nat) (h : n < 2 ^ 32 := by decide) : CIDR := ⟨.v4, ⟨n, h⟩, p⟩

def CIDR.v6 (n p : Nat) (h : n < 2 ^ 128 := by decide) : CIDR := ⟨.v6, ⟨n, h⟩, p⟩

private def lan24 : CIDR := CIDR.v4 0xC0A80100 24          -- 192.168.1.0/24
private def lanHost : IPAddr := IPAddr.v4 0xC0A80114        -- 192.168.1.20
private def otherHost : IPAddr := IPAddr.v4 0xC0A80214      -- 192.168.2.20
private def mapped : IPAddr := IPAddr.v6 0xFFFFC0000201     -- ::ffff:192.0.2.1
private def plainV4 : IPAddr := IPAddr.v4 0xC0000201        -- 192.0.2.1

-- CIDR の整形式性: host bits が 0 でない `192.168.1.5/24` と、幅を超える prefix は整形式でない。
#guard decide lan24.WF
#guard !decide (CIDR.v4 0xC0A80105 24).WF
#guard !decide (CIDR.v4 0 33).WF
#guard decide (CIDR.v4 0 0).WF && decide (CIDR.v6 0 0).WF
-- 区間の端点。`/0` の上端は幅の最大値であり、`2 ^ width` を値に持たない。
#guard lan24.hi == 0xC0A801FF
#guard (CIDR.v4 0 0).hi == 2 ^ 32 - 1
#guard (CIDR.v6 0 0).hi == 2 ^ 128 - 1
-- 所属。
#guard decide (lan24.Mem lanHost) && !decide (lan24.Mem otherHost)
-- IPv4 を射影した IPv6 は IPv6 の値であり、IPv4 の `/0` にも IPv4 の完全一致にも所属しない。
#guard !decide ((CIDR.v4 0 0).Mem mapped)
#guard !decide ((IPPattern.exact plainV4).Matches mapped)
#guard decide ((CIDR.v6 0xFFFF00000000 96).Mem mapped)
#guard !decide ((CIDR.v6 0 0).Mem plainV4)
-- `/32` と完全一致は正規化の後に同じ原子になり、`/24` はそのまま残る。
#guard (IPPattern.cidr (CIDR.v4 0xC0A8010A 32)).normalize == .exact (IPAddr.v4 0xC0A8010A)
#guard (IPPattern.cidr (CIDR.v6 1 128)).normalize == .exact (IPAddr.v6 1)
#guard (IPPattern.cidr lan24).normalize == .cidr lan24
#guard decide (Range.host (.ip (.cidr (CIDR.v4 0xC0A8010A 32)))).normalize.Canonical
-- ホスト名のパターンは IP の対象を含まず、IP のパターンはホスト名の対象を含まない。
#guard !decide ((HostPattern.name (.many ["0", "0", "1"])).Matches (.ip (IPAddr.v4 0x7F000001)))
#guard !decide ((HostPattern.ip (.cidr (CIDR.v4 0 0))).Matches (.name ["localhost"]))
-- ホスト名の exact・one・many。
#guard decide ((NamePattern.one ["example", "com"]).Matches ["api", "example", "com"])
#guard !decide ((NamePattern.one ["example", "com"]).Matches ["a", "b", "example", "com"])
#guard decide ((NamePattern.many ["example", "com"]).Matches ["a", "b", "example", "com"])
#guard !decide ((NamePattern.many ["example", "com"]).Matches ["example", "com"])
-- パスの木は幹を含み、`/data/**` は `/database` を含まない。
#guard decide ((PathPattern.tree ["data"]).Matches ["data"])
#guard !decide ((PathPattern.tree ["data"]).Matches ["database"])
-- エンドポイント。
#guard decide ((Range.endpoint ⟨.ip (.cidr lan24), ⟨80, 80⟩⟩).Mem (.endpoint ⟨.ip lanHost, 80⟩))
#guard !decide ((Range.endpoint ⟨.ip (.cidr lan24), ⟨80, 80⟩⟩).Mem (.endpoint ⟨.ip lanHost, 81⟩))
#guard !decide (PortRange.WF ⟨445, 443⟩)
-- 種類の違う対象は非 Top の範囲に所属しない。Top は全てを含むが、種類に相対的な所属は種類を見る。
#guard !decide ((Range.pathExact ["data"]).Mem (.host (.name ["data"])))
#guard decide (Range.top.Mem (.host (.name ["data"])))
#guard decide (Range.top.MemK .host (.host (.name ["data"])))
#guard !decide (Range.top.MemK .path (.endpoint ⟨.name ["a", "example"], 443⟩))
-- 整形式性。
#guard decide (Range.pathExact ["data", "a"]).WF
#guard !decide (Range.pathExact ["data", ".."]).WF
#guard !decide (Range.host (.name (.exact ["127", "0", "0", "1"]))).WF
#guard decide (Range.host (.name (.exact ["localhost"]))).WF
#guard (Port.ofInt? 65535).isSome && (Port.ofInt? 65536).isNone && (Port.ofInt? (-1)).isNone

end Benitoite.Scope.Domain
