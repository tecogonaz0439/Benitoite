import Benitoite.Scope.IPCover
import Benitoite.Release.Refinement.AtPatternText
import Benitoite.Release.Refinement.CoverageRefinement

/-! # IPv4 射影の IPv6 だけを表す host の条件

正規な完全一致又は CIDR の host の条件の全体が、IPv4 射影の IPv6 の `::ffff:0.0.0.0/96` に入るかを判定する
（設計書 01-07「閉じた範囲引数」）。範囲の代数は射影形も IPv6 の値として扱い、この判定は範囲の意味を変えない補助の
判定である。

- 判定 `IPPattern.MappedOnly` は、正規な条件に所属する全アドレスが射影形であることと同値である
  （`IPPattern.mappedOnly_iff`）。完全一致ではアドレスが射影形であること、CIDR では IPv6 で prefix の長さが96以上かつ
  ネットワークの上位96ビットが `::ffff` であることである（`IPPattern.mappedOnly_exact_iff`・
  `IPPattern.mappedOnly_cidr_iff`）。host の条件と、範囲の式の host の欄（host の範囲と endpoint の範囲）にも同じ判定を
  使う。
- 判定の成り立つ条件に所属する対象は、URL の対象の解析（`parseUrlTarget`）が受け入れる端点にならない
  （`RangeExpr.MappedHostOnly.not_url_target`）。
- 判定は範囲の所属・型付け・網羅性の定義を変えない。判定の成り立つ範囲は空でなく、所属の述語を仮定にしても論理は
  矛盾を導かず（`RangeExpr.MappedHostOnly.not_refuted`）、所属の篩を付けた型は腕のない照合で網羅されない
  （`RangeExpr.MappedHostOnly.not_exhaustive_nil`）。範囲の値は型付けで受理される
  （`RangeExpr.MappedHostOnly.scopePattern_typed`）。
-/
namespace Benitoite.Release.Refinement
open Scope.Domain

/-- IPv4 射影の IPv6 の全体 `::ffff:0.0.0.0/96`。 -/
def mappedBlock : IPPattern := .cidr ⟨.v6, ⟨0xFFFF * 2 ^ 32, by decide⟩, 96⟩

/-- `/96` への所属は、URL の対象の解析が拒否する射影形の判定と一致する。 -/
theorem mappedBlock_matches_iff (a : IPAddr) :
    mappedBlock.Matches a ↔ isIPv4MappedHost (.ip a) = true := by
  rcases a with ⟨_ | _, bits⟩
  · simp [mappedBlock, IPPattern.Matches, CIDR.Mem, isIPv4MappedHost]
  · have := bits.isLt
    simp only [Family.width] at this
    simp only [mappedBlock, IPPattern.Matches, CIDR.Mem, CIDR.lo, CIDR.hi, CIDR.blockSize, CIDR.hostBits,
      Family.width, isIPv4MappedHost, beq_iff_eq, true_and]
    omega

/-- 正規な完全一致又は CIDR の全体が `::ffff:0.0.0.0/96` に入る。警告の判定であり、範囲の意味を変えない。 -/
def IPPattern.MappedOnly (p : IPPattern) : Prop := p.WF ∧ p.Canonical ∧ mappedBlock.Covers p

instance (p : IPPattern) : Decidable (IPPattern.MappedOnly p) := by
  unfold IPPattern.MappedOnly IPPattern.Covers; infer_instance

/-- 判定は、正規な条件に所属する全アドレスが射影形であることと同値である。 -/
theorem IPPattern.mappedOnly_iff (p : IPPattern) :
    IPPattern.MappedOnly p ↔ p.WF ∧ p.Canonical ∧ ∀ a, p.Matches a → isIPv4MappedHost (.ip a) = true := by
  unfold IPPattern.MappedOnly
  constructor
  · rintro ⟨hw, hc, hcov⟩
    exact ⟨hw, hc, fun a ha => (mappedBlock_matches_iff a).mp (hcov.sound ha)⟩
  · rintro ⟨hw, hc, h⟩
    exact ⟨hw, hc, (IPPattern.covers_iff hw).mpr fun a ha => (mappedBlock_matches_iff a).mpr (h a ha)⟩

/-- 完全一致の判定は、そのアドレスが射影形であることである。 -/
theorem IPPattern.mappedOnly_exact_iff (a : IPAddr) :
    IPPattern.MappedOnly (.exact a) ↔ isIPv4MappedHost (.ip a) = true := by
  simp only [IPPattern.MappedOnly, IPPattern.WF, IPPattern.Canonical, true_and, IPPattern.covers_exact_iff,
    mappedBlock_matches_iff]

private theorem add_le_of_dvd {d a b : Nat} (ha : d ∣ a) (hb : d ∣ b) (h : a < b) : a + d ≤ b := by
  obtain ⟨x, rfl⟩ := ha
  obtain ⟨y, rfl⟩ := hb
  have hxy : x < y := Nat.lt_of_mul_lt_mul_left h
  have : d * (x + 1) ≤ d * y := Nat.mul_le_mul_left d hxy
  simpa [Nat.mul_add] using this

/-- CIDR の判定は数値で決まる。正規な IPv6 の CIDR で、prefix の長さが96以上であり、ネットワークの上位96ビットが
`::ffff` の値である。 -/
theorem IPPattern.mappedOnly_cidr_iff (c : CIDR) :
    IPPattern.MappedOnly (.cidr c) ↔ c.WF ∧ c.prefixLen < c.family.width ∧ c.family = .v6 ∧
      96 ≤ c.prefixLen ∧ c.network.val / 2 ^ 32 = 0xFFFF := by
  rcases c with ⟨family, network, len⟩
  simp only [IPPattern.MappedOnly, IPPattern.WF, IPPattern.Canonical, IPPattern.Covers, mappedBlock,
    IPPattern.family, IPPattern.lo, IPPattern.hi, CIDR.lo, CIDR.hi, CIDR.blockSize, CIDR.hostBits]
  constructor
  · rintro ⟨hw, hc, rfl, hlo, hhi⟩
    have hle := hw.1
    simp only [Family.width] at hle hc hlo hhi ⊢
    have hpos : 0 < 2 ^ (128 - len) := Nat.pow_pos (by decide)
    have hpow : 2 ^ (128 - len) ≤ 2 ^ 32 := by omega
    have h32 : 128 - len ≤ 32 := (Nat.pow_le_pow_iff_right (by decide)).mp hpow
    exact ⟨hw, hc, trivial, by omega, by omega⟩
  · rintro ⟨hw, hc, rfl, hlen, hnet⟩
    simp only [Family.width] at hc hlen ⊢
    have hnet' : 0xFFFF * 2 ^ 32 ≤ network.val ∧ network.val < 0xFFFF * 2 ^ 32 + 2 ^ 32 := by omega
    obtain ⟨d, hd⟩ : 2 ^ (128 - len) ∣ 2 ^ 32 := Nat.pow_dvd_pow 2 (by omega)
    have hdn : 2 ^ (128 - len) ∣ network.val := Nat.dvd_of_mod_eq_zero hw.2
    have hdl : 2 ^ (128 - len) ∣ 0xFFFF * 2 ^ 32 := Nat.dvd_trans ⟨d, hd⟩ (Nat.dvd_mul_left _ _)
    have hdr : 2 ^ (128 - len) ∣ network.val - 0xFFFF * 2 ^ 32 := Nat.dvd_sub hdn hdl
    have hr := add_le_of_dvd hdr ⟨d, hd⟩ (by omega)
    refine ⟨hw, hc, trivial, hnet'.1, ?_⟩
    omega

/-- host の条件の判定。ホスト名の条件は IP の対象を含まないので成り立たない。 -/
def HostPattern.MappedOnly : HostPattern → Prop
  | .ip p => IPPattern.MappedOnly p
  | .name _ => False

instance (p : HostPattern) : Decidable (HostPattern.MappedOnly p) := by
  cases p <;> unfold HostPattern.MappedOnly <;> infer_instance

/-- host の条件の判定は、正規な条件に所属する全 host の対象が射影形であることと同値である。 -/
theorem HostPattern.mappedOnly_iff (p : HostPattern) :
    HostPattern.MappedOnly p ↔ p.WF ∧ p.Canonical ∧ ∀ t, p.Matches t → isIPv4MappedHost t = true := by
  cases p with
  | ip q =>
    simp only [HostPattern.MappedOnly, IPPattern.mappedOnly_iff, HostPattern.WF, HostPattern.Canonical]
    constructor
    · rintro ⟨hw, hc, h⟩
      refine ⟨hw, hc, ?_⟩
      rintro (w | a) ht
      · simp [HostPattern.Matches] at ht
      · exact h a ht
    · rintro ⟨hw, hc, h⟩
      exact ⟨hw, hc, fun a ha => h (.ip a) ha⟩
  | name q =>
    simp only [HostPattern.MappedOnly, false_iff]
    rintro ⟨_, _, h⟩
    obtain ⟨w, hw⟩ := NamePattern.nonempty q
    simpa [isIPv4MappedHost] using h (.name w) hw

/-- 範囲の式の host の欄。host の範囲と endpoint の範囲の host の条件であり、ほかの範囲は持たない。 -/
def RangeExpr.hostPattern? : RangeExpr → Option HostPattern
  | .absolute (.host p) => some p
  | .absolute (.endpoint e) => some e.host
  | _ => none

/-- 整形式の範囲の式の host の欄が射影形だけを表す。 -/
def RangeExpr.MappedHostOnly (r : RangeExpr) : Prop :=
  r.WF ∧ match r.hostPattern? with
    | some p => HostPattern.MappedOnly p
    | none => False

instance (r : RangeExpr) : Decidable r.MappedHostOnly := by
  unfold RangeExpr.MappedHostOnly
  cases r.hostPattern? <;> infer_instance

/-- 判定の成り立つ範囲は、host の範囲か endpoint の範囲である。 -/
theorem RangeExpr.MappedHostOnly.cases {r : RangeExpr} (h : r.MappedHostOnly) :
    (∃ p, r = .absolute (.host p) ∧ HostPattern.MappedOnly p) ∨
      ∃ e, r = .absolute (.endpoint e) ∧ e.WF ∧ HostPattern.MappedOnly e.host := by
  obtain ⟨hw, hm⟩ := h
  rcases r with (_ | _ | p | e) | _ | _
  all_goals simp only [RangeExpr.hostPattern?] at hm
  · exact .inl ⟨p, rfl, hm⟩
  · exact .inr ⟨e, rfl, hw, hm⟩

/-- 判定の成り立つ範囲に所属する対象の host は、どの起点の値でも射影形である。 -/
theorem RangeExpr.MappedHostOnly.target_mapped {r : RangeExpr} (h : r.MappedHostOnly)
    {σ : PathEnv} {k : Kind} {t : Target} (hm : r.Mem σ k t) :
    ∃ host, (t = .host host ∨ ∃ port, t = .endpoint ⟨host, port⟩) ∧ isIPv4MappedHost host = true := by
  obtain ⟨_, hm⟩ := hm
  rcases h.cases with ⟨p, rfl, hp⟩ | ⟨e, rfl, _, hp⟩
  all_goals simp only [RangeExpr.resolve, List.mem_singleton, exists_eq_left] at hm
  all_goals obtain ⟨_, _, hall⟩ := (HostPattern.mappedOnly_iff _).mp hp
  · cases t <;> simp only [Range.Mem] at hm
    exact ⟨_, .inl rfl, hall _ hm⟩
  · cases t with
    | endpoint x => exact ⟨x.host, .inr ⟨x.port, rfl⟩, hall _ hm.1⟩
    | _ => simp only [Range.Mem] at hm

/-- URL の対象の解析は、射影形の host の端点を返さない。 -/
theorem parseUrlTarget_not_mapped {s : String} {e : Endpoint}
    (h : parseUrlTarget s = some (.endpoint e)) : isIPv4MappedHost e.host = false := by
  obtain ⟨⟨authority, port⟩, _, ht⟩ := Option.bind_eq_some_iff.mp h
  obtain ⟨target, _, ht⟩ := Option.bind_eq_some_iff.mp ht
  cases target with
  | endpoint x =>
    simp only at ht
    split at ht
    · cases ht
    · rename_i hn
      cases ht
      simpa using hn
  | _ => cases ht

/-- 判定の成り立つ範囲に所属する対象は、URL の対象の解析が受け入れる端点ではない。 -/
theorem RangeExpr.MappedHostOnly.not_url_target {r : RangeExpr} (h : r.MappedHostOnly)
    {σ : PathEnv} {k : Kind} {s : String} {t : Target} (ht : parseUrlTarget s = some t) :
    ¬ r.Mem σ k t := by
  intro hm
  obtain ⟨host, ht', hmapped⟩ := h.target_mapped hm
  have hk := parseUrlTarget_kind ht
  rcases ht' with rfl | ⟨port, rfl⟩
  · cases hk
  · simp [parseUrlTarget_not_mapped ht] at hmapped

/-- 保持した要求の対象（`Http.checkRequestIn` が読む URL）も、判定の成り立つ範囲に所属しない。 -/
theorem RangeExpr.MappedHostOnly.not_request_target {r : RangeExpr} (h : r.MappedHostOnly)
    {σ : PathEnv} {k : Kind} {v : Val} {t : Target} (ht : v.reqTarget = some t) : ¬ r.Mem σ k t := by
  unfold Val.reqTarget at ht
  split at ht
  · exact h.not_url_target ht
  · cases ht

/-- 判定の成り立つ範囲は、名前の種類に合う整形式の対象を含む（範囲を空にしない）。 -/
theorem RangeExpr.MappedHostOnly.witness {r : RangeExpr} (h : r.MappedHostOnly)
    {k : Kind} (hk : r.FitsKind k) : ∃ t, t.kind = k ∧ t.WF ∧ SnapshotMem none k r t := by
  rcases h.cases with ⟨p, rfl, hp⟩ | ⟨e, rfl, hw, hp⟩
  · cases p with
    | name q => exact hp.elim
    | ip q =>
      obtain ⟨a, ha⟩ := IPPattern.nonempty q
      have hk' : k = .host := by
        rcases hk with hk | hk <;> simp [Range.kind?] at hk; exact hk.symm
      subst hk'
      exact ⟨.host (.ip a), rfl, trivial, rfl, ha⟩
  · rcases e with ⟨host, ports⟩
    cases host with
    | name q => exact hp.elim
    | ip q =>
      obtain ⟨a, ha⟩ := IPPattern.nonempty q
      have hk' : k = .endpoint := by
        rcases hk with hk | hk <;> simp [Range.kind?] at hk; exact hk.symm
      subst hk'
      exact ⟨.endpoint ⟨.ip a, ports.lo⟩, rfl, trivial, rfl, ha, Nat.le_refl _, hw.2⟩

/-- 所属の述語は、判定の成り立つ範囲の対象を保持した値の自己観測で真に評価される。 -/
theorem RangeExpr.MappedHostOnly.member_true {r : RangeExpr} (h : r.MappedHostOnly)
    {k : Kind} (hk : r.FitsKind k) :
    ∃ t, (Pred.member k (.var 0) r).evalWith (selfModel (fun _ => none) (.checked t)) = some true := by
  obtain ⟨t, htk, htw, hm⟩ := h.witness hk
  have habs : ∃ q, r = .absolute q := by
    rcases h.cases with ⟨p, rfl, _⟩ | ⟨e, rfl, _⟩ <;> exact ⟨_, rfl⟩
  obtain ⟨q, rfl⟩ := habs
  refine ⟨t, ?_⟩
  simp [Pred.evalWith, Pred.atomReady, Pred.atomValue, memberReady, observeAs, selfModel, selfObservation,
    Val.toTerm?, Term.observe, Term.interpret, Observation.sort, resolveSnapshot, htk, htw, h.1, hk, hm]

/-- 判定の成り立つ範囲への所属を仮定にしても、論理は矛盾を導かない。 -/
theorem RangeExpr.MappedHostOnly.not_refuted {r : RangeExpr} (h : r.MappedHostOnly)
    {k : Kind} (hk : r.FitsKind k) : ¬ Entails [Pred.member k (.var 0) r] .falsity := by
  intro he
  obtain ⟨t, ht⟩ := h.member_true hk
  have hf := he.sound (selfModel (fun _ => none) (.checked t)) (by
    intro q hq
    simp only [List.mem_singleton] at hq
    subst hq
    exact Pred.evalWith_sound ht)
  simp [Pred.interpret, Pred.atomValue] at hf

/-- 判定の成り立つ範囲への所属の篩を付けた範囲付きの型は、腕のない照合で網羅されない。 -/
theorem RangeExpr.MappedHostOnly.not_exhaustive_nil {r : RangeExpr} (h : r.MappedHostOnly)
    {k : Kind} (hk : r.FitsKind k) (P : Program) (o : OpaqueName) (ix : RangeIx) :
    ¬ Exhaustive P (.refined (.scoped o k ix) (.member k (.var 0) r)) [] := by
  intro hex
  obtain ⟨t, ht⟩ := h.member_true hk
  have hi : Inhabits P (.refined (.scoped o k ix) (.member k (.var 0) r)) (.checked t) :=
    .refined .scoped (by rw [RefinementPossible, ht]; simp)
  obtain ⟨_, hp, _⟩ := hex _ ((Inhabits.norm_all_iff _ _).mpr hi)
  cases hp

/-- 判定の成り立つ範囲の値は、範囲の pattern の型で型付けされる（警告だけで拒否しない）。 -/
theorem RangeExpr.MappedHostOnly.scopePattern_typed {r : RangeExpr} (h : r.MappedHostOnly)
    {k : Kind} (hk : r.FitsKind k) {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx}
    {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} :
    HasTypeVQ P B Ψ Q C Γ Φ (.scopePattern r) (.scopePattern k) := by
  have hc : r.Canonical := by
    rcases h.cases with ⟨p, rfl, hp⟩ | ⟨e, rfl, _, hp⟩
    · cases p with
      | name q => exact hp.elim
      | ip q => exact hp.2.1
    · rcases e with ⟨host, ports⟩
      cases host with
      | name q => exact hp.elim
      | ip q => exact hp.2.1
  exact .V_ScopePattern h.1 hc hk

/-- 文字列の host の条件 `::ffff:0.0.0.0/96` は `/96` の全体として読まれる。 -/
example : parseHostPatternText "::ffff:0.0.0.0/96" = some (.ip mappedBlock) := by cbv

/-- 射影形の完全一致・同じ意味の `/128`・`/96` の内側の CIDR は判定が成り立つ。 -/
example : (parseHostPatternText "::ffff:192.0.2.1").map (decide <| HostPattern.MappedOnly ·) = some true ∧
    (parseHostPatternText "::ffff:192.0.2.1/128").map (decide <| HostPattern.MappedOnly ·) = some true ∧
    (parseHostPatternText "::ffff:192.0.2.0/120").map (decide <| HostPattern.MappedOnly ·) = some true := by
  cbv

/-- 射影形以外も含む CIDR・IPv4・IPv4 互換の形は判定が成り立たない。host bits の残る `/95` は解析が拒否する
（警告を重ねて受理しない）。ホスト名の条件は定義により成り立たない。 -/
example : (parseHostPatternText "::/0").map (decide <| HostPattern.MappedOnly ·) = some false ∧
    (parseHostPatternText "::fffe:0:0/95").map (decide <| HostPattern.MappedOnly ·) = some false ∧
    (parseHostPatternText "192.0.2.1").map (decide <| HostPattern.MappedOnly ·) = some false ∧
    (parseHostPatternText "::c000:201").map (decide <| HostPattern.MappedOnly ·) = some false ∧
    parseHostPatternText "::ffff:0.0.0.0/95" = none := by
  cbv

/-- 全ポートの `::ffff:0.0.0.0/96` の endpoint の範囲は、判定が成り立ち、URL の対象と保持した要求の対象を含まないが、空にならず、
所属の仮定から矛盾を導かず、腕のない照合で網羅されず、範囲の pattern の値は型付けで受理される。 -/
example (P : Program) (B : Builtins) (σ : PathEnv) (s : String) (t : Target) (ht : parseUrlTarget s = some t)
    (v : Val) (t' : Target) (hv : v.reqTarget = some t') :
    (RangeExpr.endpoint ⟨.ip mappedBlock, ⟨0, 65535⟩⟩).MappedHostOnly ∧
      ¬ (RangeExpr.endpoint ⟨.ip mappedBlock, ⟨0, 65535⟩⟩).Mem σ .endpoint t ∧
      ¬ (RangeExpr.endpoint ⟨.ip mappedBlock, ⟨0, 65535⟩⟩).Mem σ .endpoint t' ∧
      ¬ Entails [.member .endpoint (.var 0) (.endpoint ⟨.ip mappedBlock, ⟨0, 65535⟩⟩)] .falsity ∧
      ¬ Exhaustive P (.refined (.scoped "Http.RequestIn" .endpoint (.fixed (.endpoint ⟨.ip mappedBlock, ⟨0, 65535⟩⟩)))
        (.member .endpoint (.var 0) (.endpoint ⟨.ip mappedBlock, ⟨0, 65535⟩⟩))) [] ∧
      HasTypeVQ P B (fun _ => none) Qempty [] [] [] (.scopePattern (.endpoint ⟨.ip mappedBlock, ⟨0, 65535⟩⟩))
        (.scopePattern .endpoint) := by
  have h : (RangeExpr.endpoint ⟨.ip mappedBlock, ⟨0, 65535⟩⟩).MappedHostOnly := by decide
  have hk : (RangeExpr.endpoint ⟨.ip mappedBlock, ⟨0, 65535⟩⟩).FitsKind .endpoint := by decide
  exact ⟨h, h.not_url_target ht, h.not_request_target hv, h.not_refuted hk, h.not_exhaustive_nil hk P _ _, h.scopePattern_typed hk⟩

/-- 数値の判定と同じ結果になる。射影形のアドレスの完全一致・`/96` 自身・`/97` は成り立ち、`/95`（正規な
`::fffe:0:0/95`）は成り立たない。 -/
example : IPPattern.MappedOnly (.exact (IPAddr.mapped ⟨0xC0000201, by decide⟩)) ∧ IPPattern.MappedOnly mappedBlock ∧
    IPPattern.MappedOnly (.cidr ⟨.v6, ⟨0xFFFF * 2 ^ 32, by decide⟩, 97⟩) ∧
    ¬ IPPattern.MappedOnly (.cidr ⟨.v6, ⟨0xFFFE * 2 ^ 32, by decide⟩, 95⟩) := by
  refine ⟨(IPPattern.mappedOnly_exact_iff _).mpr (by decide), ?_, ?_, ?_⟩
  · exact (IPPattern.mappedOnly_cidr_iff _).mpr ⟨by decide, by decide, rfl, by decide, by decide⟩
  · exact (IPPattern.mappedOnly_cidr_iff _).mpr ⟨by decide, by decide, rfl, by decide, by decide⟩
  · rw [IPPattern.mappedOnly_cidr_iff]; decide

/-- 判定の三つの条件は互いに独立である。host bits の残る `/97`（整形式でない）、`/128` の CIDR（正規形でない）、
`::/0`（`/96` に入らない）は、それぞれほかの二つの条件を満たして判定が成り立たない。endpoint の範囲ではポートの区間の
整形式も条件である。 -/
example : (¬ (IPPattern.cidr ⟨.v6, ⟨0xFFFF * 2 ^ 32 + 1, by decide⟩, 97⟩).WF ∧
      (IPPattern.cidr ⟨.v6, ⟨0xFFFF * 2 ^ 32 + 1, by decide⟩, 97⟩).Canonical ∧
      mappedBlock.Covers (.cidr ⟨.v6, ⟨0xFFFF * 2 ^ 32 + 1, by decide⟩, 97⟩)) ∧
    ((IPPattern.cidr ⟨.v6, ⟨0xFFFF * 2 ^ 32, by decide⟩, 128⟩).WF ∧
      ¬ (IPPattern.cidr ⟨.v6, ⟨0xFFFF * 2 ^ 32, by decide⟩, 128⟩).Canonical ∧
      mappedBlock.Covers (.cidr ⟨.v6, ⟨0xFFFF * 2 ^ 32, by decide⟩, 128⟩)) ∧
    ((IPPattern.cidr ⟨.v6, ⟨0, by decide⟩, 0⟩).WF ∧ (IPPattern.cidr ⟨.v6, ⟨0, by decide⟩, 0⟩).Canonical ∧
      ¬ mappedBlock.Covers (.cidr ⟨.v6, ⟨0, by decide⟩, 0⟩)) ∧
    HostPattern.MappedOnly (.ip mappedBlock) ∧ ¬ (RangeExpr.endpoint ⟨.ip mappedBlock, ⟨5, 3⟩⟩).MappedHostOnly := by
  decide

/-- URL の対象の解析が返す端点（ループバックの HTTPS）は、`/96` の endpoint の範囲に所属しない。 -/
example (σ : PathEnv) :
    ¬ (RangeExpr.endpoint ⟨.ip mappedBlock, ⟨0, 65535⟩⟩).Mem σ .endpoint
      (.endpoint ⟨.ip (.v4 2130706433 (by decide)), ⟨443, by decide⟩⟩) :=
  RangeExpr.MappedHostOnly.not_url_target (by decide) parseUrlTarget_https_loopback

end Benitoite.Release.Refinement
