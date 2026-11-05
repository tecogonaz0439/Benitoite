import Benitoite.Scope.RangeCover
import Benitoite.Release.Refinement.ScopeCoverage
import Benitoite.Release.Refinement.RangeFormation

/-! # 種類 host の範囲パラメータ

範囲の変数と範囲パラメータの種類は、対象の種類の path・host・endpoint である（設計書 01-12「操作の対象の範囲の
領域と被覆」）。本ファイルは種類 host の範囲の変数の具体化と置換の性質を示す。

- 種類 host に置ける範囲の式は、Top と host の条件の絶対形だけである（`RangeExpr.fitsKind_host_iff`）。基準からの
  条件と `{secrets}` は置けない。組込みの関数の範囲の具体化の許容も、種類 host の位置にはこの形だけを許す
  （`Builtins.RangeAdmissible.host_image`・`Builtins.RangeAdmissible.single_host_iff`）。
- 種類 host の範囲の解決と所属は起点の値を読まない（`RangeExpr.mem_host_env`・`RangeExpr.snapshotMem_host`）。
  被覆はどの内側でも所属の包含と同値である（`RangeExpr.covers_host_iff`）。
- 範囲の具体化は、種類 host の範囲変数を種類 host の閉じた範囲へ置き換え、具体化した範囲の所属の包含から範囲付きの
  型の部分型が従う（`Ty.instR_scoped_rvar`・`Ty.LeQ.scoped_host_of_mem`）。
- 範囲の位置を持たない署名も種類 host の範囲パラメータを宣言でき、署名の形成の条件を満たし、具体化は型を変えない
  （末尾の例）。
-/
namespace Benitoite.Release.Refinement
open Scope.Domain

/-- 種類 host に置ける範囲の式は、Top と host の条件の絶対形である。 -/
theorem RangeExpr.fitsKind_host_iff (r : RangeExpr) :
    r.FitsKind .host ↔ r = .absolute .top ∨ ∃ p, r = .host p := by
  rcases r with (_ | _ | p | _) | _ | _ <;>
    simp [RangeExpr.FitsKind, Range.FitsKind, Range.kind?]

/-- 種類 host の範囲の式は絶対形であり、どの起点の値でも同じ一つの範囲へ解決する。 -/
theorem RangeExpr.host_absolute {r : RangeExpr} (h : r.FitsKind .host) :
    ∃ q, r = .absolute q ∧ q.FitsKind .host ∧ ∀ σ, r.resolve σ = some [q] := by
  rcases (RangeExpr.fitsKind_host_iff r).mp h with rfl | ⟨p, rfl⟩
  · exact ⟨_, rfl, Range.top_fitsKind _, fun _ => rfl⟩
  · exact ⟨_, rfl, h, fun _ => rfl⟩

/-- 種類 host の範囲への所属は起点の値を読まない。 -/
theorem RangeExpr.mem_host_env {r : RangeExpr} (h : r.FitsKind .host) (σ σ' : PathEnv) (k : Kind)
    (t : Target) : r.Mem σ k t ↔ r.Mem σ' k t := by
  obtain ⟨q, rfl, _, hr⟩ := RangeExpr.host_absolute h
  simp only [RangeExpr.Mem, hr]

/-- 種類 host の範囲の、起点の値を添えた所属は、起点の値の有効性と起点の値なしの所属である。 -/
theorem RangeExpr.snapshotMem_host {r : RangeExpr} (h : r.FitsKind .host) (σ : PathEnv) (t : Target) :
    SnapshotMem (some σ) .host r t ↔ σ.Valid ∧ SnapshotMem none .host r t := by
  obtain ⟨q, rfl, _, hr⟩ := RangeExpr.host_absolute h
  simp only [SnapshotMem, RangeExpr.Mem, hr, List.mem_singleton, exists_eq_left, Range.MemK]

/-- 被覆の完全性の証明で所属を読む起点の値。種類 host の所属は起点の値を読まない。 -/
private def PathEnv.empty : PathEnv := ⟨[], [], [], none, none, none⟩

/-- 種類 host の範囲の被覆は、内側が整形式なら、どの内側（Top を含む）でも種類 host の所属の包含と同値である。 -/
theorem RangeExpr.covers_host_iff {r s : RangeExpr} (hr : r.FitsKind .host) (hs : s.FitsKind .host)
    (hw : s.WF) : r.Covers s ↔ ∀ σ t, s.Mem σ .host t → r.Mem σ .host t := by
  constructor
  · exact fun h σ _ => h.mem σ
  · intro h
    obtain ⟨q, rfl, hq, hqr⟩ := RangeExpr.host_absolute hr
    obtain ⟨u, rfl, hu, hus⟩ := RangeExpr.host_absolute hs
    have hmem : ∀ t, u.MemK .host t → q.MemK .host t := by
      intro t ht
      have := h PathEnv.empty t (by simpa [RangeExpr.Mem, hus, Range.MemK] using ht)
      simpa [RangeExpr.Mem, hqr, Range.MemK] using this
    rw [RangeExpr.covers_absolute]
    by_cases hut : u = .top
    · subst hut
      rw [Range.covers_top_iff]
      rcases (RangeExpr.fitsKind_host_iff _).mp hr with he | ⟨p, he⟩
      · cases he; rfl
      · cases he
        exfalso
        cases p with
        | name n =>
          have := hmem (.host (.ip (.v4 0))) ⟨rfl, trivial⟩
          simp [Range.MemK, Range.Mem, HostPattern.Matches] at this
        | ip a =>
          have := hmem (.host (.name ["a"])) ⟨rfl, trivial⟩
          simp [Range.MemK, Range.Mem, HostPattern.Matches] at this
    · exact (Range.covers_iff_memK hw hut hu).mpr hmem

/-- 範囲の具体化の許容は、種類 host の位置に Top か正規な host の条件だけを許す。 -/
theorem Builtins.RangeAdmissible.host_image {B : Builtins} {b : PrimName} {s : PrimSig}
    {rs : List RangeExpr} (h : B.RangeAdmissible b s rs) {i : Nat} {r : RangeExpr}
    (hk : s.rkinds[i]? = some .host) (hr : rs[i]? = some r) :
    r = .absolute .top ∨ ∃ p, r = .host p ∧ p.WF ∧ p.Canonical := by
  have hfit := h.2.1 i r .host hr hk
  have hform := h.2.2.1 r (List.mem_of_getElem? hr)
  rcases (RangeExpr.fitsKind_host_iff r).mp hfit with rfl | ⟨p, rfl⟩
  · exact .inl rfl
  · exact .inr ⟨p, rfl, hform⟩

/-- 種類 host の範囲パラメータを一つ持つ署名の具体化の許容は、Top か、正規な host の条件で表の制約を満たすことで
ある。 -/
theorem Builtins.RangeAdmissible.single_host_iff {B : Builtins} {b : PrimName} {s : PrimSig}
    (hk : s.rkinds = [.host]) (r : RangeExpr) :
    B.RangeAdmissible b s [r] ↔
      r = .absolute .top ∨ ∃ p, r = .host p ∧ p.WF ∧ p.Canonical ∧ B.admitsR b [r] := by
  constructor
  · intro h
    rcases h.host_image (i := 0) (by simp [hk]) rfl with rfl | ⟨p, rfl, hp⟩
    · exact .inl rfl
    · rcases h.2.2.2 with ha | ha
      · cases ha _ (List.mem_singleton_self _)
      · exact .inr ⟨p, rfl, hp.1, hp.2, ha⟩
  · rintro (rfl | ⟨p, rfl, hw, hc, ha⟩)
    · refine ⟨by simp [hk], ?_, ?_, .inl (by simp)⟩
      · intro i r k hr hk'
        cases i <;> simp at hr
        subst hr
        exact Range.top_fitsKind k
      · intro r hr
        simp only [List.mem_singleton] at hr
        subst hr
        exact ⟨trivial, trivial⟩
    · refine ⟨by simp [hk], ?_, ?_, .inr ha⟩
      · intro i r k hr hk'
        cases i <;> simp [hk] at hr hk'
        subst hr hk'
        exact .inr rfl
      · intro r hr
        simp only [List.mem_singleton] at hr
        subst hr
        exact ⟨hw, hc⟩

/-- 範囲の具体化は、範囲付きの型の範囲変数を具体化の列の同じ番号の範囲へ置き換える。 -/
theorem Ty.instR_scoped_rvar (rs : List RangeExpr) (o : OpaqueName) (k : Kind) {i : Nat} {r : RangeExpr}
    (hr : rs[i]? = some r) : Ty.instR rs (.scoped o k (.rvar i)) = .scoped o k (.fixed r) := by
  simp [Ty.instR, Ty.substRAt, Ty.mapRanges, Ty.rawMapRanges, mapIx, rangeAt, Ty.norm, hr]

/-- 種類 host の範囲で具体化した範囲付きの型は、内側の範囲の所属が外側の範囲の所属に含まれるとき、外側の型の部分型
である。 -/
theorem Ty.LeQ.scoped_host_of_mem {P : Program} {Γ : Ctx} {Φ : List Pred} {o : OpaqueName}
    {r s : RangeExpr} (hr : r.FitsKind .host) (hs : s.FitsKind .host) (hw : s.WF) :
    (∀ σ t, s.Mem σ .host t → r.Mem σ .host t) →
      Ty.LeQ P Γ Φ (.scoped o .host (.fixed s)) (.scoped o .host (.fixed r)) := fun h =>
  .scoped ((RangeExpr.covers_host_iff hr hs hw).mpr h)

/-- 範囲の位置を持たない署名でも、種類 host の範囲パラメータの宣言は署名の形成の条件を満たす（範囲変数の個数は
上限であり、使う位置を要求しない）。 -/
example (P : Program) : PrimSig.Scoped P ⟨[], 0, ["text"], [.base .string], .base .unit, Eff.empty,
    (fun _ ts => ts = []), .pure, none, [.host], .untargeted⟩ := by
  constructor
  all_goals simp [PrimSig.tel, signatureTel, NamesWF, Ty.SourceScoped, Ty.WF, Tel.WF, Ty.WFList, Ty.RowsIn, Tel.RowsIn,
    Ty.RowsInList, Eff.RowsIn, Ty.RangesScoped, Tel.RangesScoped, rangesScopedTypes, Eff.RangesScoped, Eff.WF,
    Eff.empty, Eff.Canonical, Eff.norm, Ty.normTys, Ty.HasKind, kindsTel, kindsList, kindsEff, TypeCtx.kinds,
    Tel.Sorted, Ty.Sorted, sortedTys, sortedEff, Tel.Declared, Ty.Declared, declaredTys, declaredEff]

/-- 範囲の位置を持たない署名は、種類 host の範囲パラメータを宣言でき、Top と正規な host の条件で具体化でき、
具体化は引数と結果の型を変えない。基準からの条件・`{secrets}`・path の条件では具体化できない。 -/
example (B : Builtins) (b : PrimName) (p : HostPattern) (hp : p.WF ∧ p.Canonical) (ha : B.admitsR b [.host p]) :
    let s : PrimSig := ⟨[], 0, ["text"], [.base .string], .base .unit, Eff.empty, (fun _ ts => ts = []), .pure,
      none, [.host], .untargeted⟩
    B.RangeAdmissible b s [.absolute .top] ∧ B.RangeAdmissible b s [.host p] ∧
      ¬ B.RangeAdmissible b s [.path (.tree [])] ∧ ¬ B.RangeAdmissible b s [.based .cwd (.tree [])] ∧
      ¬ B.RangeAdmissible b s [.secrets] ∧
      s.params.map (Ty.instR [.host p]) = s.params ∧ Ty.instR [.host p] s.ret = s.ret := by
  intro s
  have hk : s.rkinds = [.host] := rfl
  refine ⟨(Builtins.RangeAdmissible.single_host_iff hk _).mpr (.inl rfl),
    (Builtins.RangeAdmissible.single_host_iff hk _).mpr (.inr ⟨p, rfl, hp.1, hp.2, ha⟩), ?_, ?_, ?_, ?_, ?_⟩
  · rw [Builtins.RangeAdmissible.single_host_iff hk]; simp
  · rw [Builtins.RangeAdmissible.single_host_iff hk]; simp
  · rw [Builtins.RangeAdmissible.single_host_iff hk]; simp
  · simp [s, Ty.instR, Ty.substRAt, Ty.mapRanges, Ty.rawMapRanges, Ty.norm]
  · simp [s, Ty.instR, Ty.substRAt, Ty.mapRanges, Ty.rawMapRanges, Ty.norm]

/-- 種類 host の範囲変数を持つ範囲付きの型は、host の条件で具体化すると、同じ条件の閉じた範囲の型になり、
広い条件の型の部分型になる。 -/
example (P : Program) (o : OpaqueName) :
    Ty.instR [.host (.name (.exact ["api", "example", "com"]))] (.scoped o .host (.rvar 0)) =
        .scoped o .host (.fixed (.host (.name (.exact ["api", "example", "com"])))) ∧
      Ty.LeQ P [] [] (.scoped o .host (.fixed (.host (.name (.exact ["api", "example", "com"])))))
        (.scoped o .host (.fixed (.host (.name (.one ["example", "com"]))))) := by
  refine ⟨Ty.instR_scoped_rvar _ _ _ rfl, Ty.LeQ.scoped_host_of_mem (by decide) (by decide) (by decide) ?_⟩
  intro σ t hm
  obtain ⟨hk, hm⟩ := hm
  simp only [RangeExpr.resolve, List.mem_singleton, exists_eq_left] at hm
  refine ⟨hk, .host (.name (.one ["example", "com"])), List.mem_singleton_self _, ?_⟩
  cases t with
  | host h =>
    cases h with
    | name w =>
      simp only [Range.Mem, HostPattern.Matches, NamePattern.Matches] at hm ⊢
      exact ⟨"api", hm⟩
    | ip a => simp [Range.Mem, HostPattern.Matches] at hm
  | _ => simp [Range.Mem] at hm

/-- 種類 host の範囲への所属は起点の値によらず、起点の値を添えた所属は起点の値の有効性だけを加える。 -/
example (σ σ' : PathEnv) (hσ : σ.Valid) (t : Target) :
    ((RangeExpr.host (.name (.one ["example", "com"]))).Mem σ .host t ↔
      (RangeExpr.host (.name (.one ["example", "com"]))).Mem σ' .host t) ∧
    (SnapshotMem (some σ) .host (.host (.name (.one ["example", "com"]))) t ↔
      SnapshotMem none .host (.host (.name (.one ["example", "com"]))) t) := by
  have hr : (RangeExpr.host (.name (.one ["example", "com"]))).FitsKind .host := by decide
  exact ⟨RangeExpr.mem_host_env hr σ σ' .host t,
    (RangeExpr.snapshotMem_host hr σ t).trans ⟨And.right, fun h => ⟨hσ, h⟩⟩⟩

end Benitoite.Release.Refinement
