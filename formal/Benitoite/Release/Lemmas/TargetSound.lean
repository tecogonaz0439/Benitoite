import Benitoite.Release.Lemmas.MembershipBase
import Benitoite.Release.ShapeOk
import Benitoite.Release.EffectCover

/-!
# 対象一致の条件から観測の許可を導く（L20.7）

L10.5 の許可の関係 `Eff.Allows κ` の名前の種類の関数 κ を、署名の表のデータ `effKind` に具体化する
（`Builtins.Allows`。RV-L00 中2）。対象一致の条件 `TargetAgreement` の唯一の欄 `io_target` と、旧の条件
`CoreAssumptions` の形の検査 `io_op` から、IO の組み込みの関数の一回の呼び出しが報告する観測の対象は、具体化した
署名の効果の同じ名前の原子が許すことを示す（L00.03 のモデルの `target_sound` の本番版。`Builtins.TargetAgreement.obs_allowed`）。

この補題は、継続を通した伝播と事象の遷移を含む一段の対象健全性（L30.4）の部品であり、四つの主定理は
`TargetAgreement` に依存しない。旧 Top の形の完全性（実装が作用した対象をすべて観測に含む。問 10）は文言として
信頼し、この補題も使わない（設計書 07-04「形式化で仮定するもの」）。
-/

namespace Benitoite.Release

open Scope.Signature (Ix)

variable {P : Program} {B : Builtins}

/-- 効果 ε が名前 l の操作の対象 t を許す。許可の関係 `Eff.Allows` の名前の種類の関数を、署名の表のデータ
`effKind` に具体化したもの（L10.5 の κ の具体化）。 -/
abbrev Builtins.Allows (B : Builtins) (ε : Eff) (l : EffName) (t : Scope.Domain.Target) : Prop :=
  Eff.Allows B.effKind ε l t

/-- 許される対象の種類は、エフェクトの名前の種類（表のデータ）に合う。 -/
theorem Builtins.Allows.kind {ε : Eff} {l : EffName} {t : Scope.Domain.Target} (h : B.Allows ε l t) :
    B.effKind l = some t.kind :=
  Eff.Allows.kind h

/-- 被覆の健全性（`Eff.Covers.sound`）の、表の `effKind` での読み。 -/
theorem Builtins.Allows.of_covers {ε ε' : Eff} (h : ε.Covers ε') {l : EffName} {t : Scope.Domain.Target}
    (ha : B.Allows ε' l t) : B.Allows ε l t :=
  Eff.Covers.sound h ha

/-- 対象一致の条件から観測の許可へ。IO の組み込みの関数を範囲の列 rs で具体化し、型の付いた引数で呼んだとき、
応答の関係が許す観測の対象はすべて、具体化した署名の効果の同じ名前 l の原子が許す。

- 対象なしの形: 観測は空である。
- 旧 Top の形: 観測は宣言した種類の対象であり、名前だけの（Top の）原子が許す。
- 単一の対象の形: 範囲の列は一つの範囲 R であり、対象の位置の引数は `O[R]` の型を持つ。引数が検査済みの対象 t の
  値なら、観測はちょうど `[t]` で、t は値の型付け（V-Checked）により R に属し、種類は `valKind`・`effKind` の一致から
  名前の種類に合う。引数が不透明型の定数なら、R は Top であり、旧 Top の形として読む。 -/
theorem Builtins.TargetAgreement.obs_allowed (hc : B.CoreAssumptions P) (ht : B.TargetAgreement P)
    {Ψ : StoreTy} {b : PrimName} {s : PrimSig} {rs : List Scope.Domain.Range} {ts : List Ty} {es : List Eff}
    {ws : List Val} {o : Outcome} {obs : List Scope.Domain.Target}
    (hb : B.sig b = some s) (hk : s.kind = .io ∨ s.kind = .exit) (hR : B.RangeAdmissible b s rs)
    (htl : ts.length = s.ntys) (hel : es.length = s.neffs) (had : s.admits [] ts)
    (hw : HasTypeVs P B Ψ [] [] ws ((s.inst rs).params.map (Ty.subst ts es)))
    (hr : B.ioResponse b ts es ws o obs) :
    ∃ l, s.opEff = some l ∧ ∀ t ∈ obs, B.Allows (s.inst rs).eff l t := by
  have htgt := ht.io_target Ψ b s rs ts es ws o obs hb hk hR htl hel had hw hr
  obtain ⟨l, bs, h1, -, -, -, h5⟩ := hc.io_op b s hb hk
  refine ⟨l, h1, ?_⟩
  cases hs : s.shape with
  | untargeted =>
      have hobs : obs = [] := by
        simpa [PrimSig.shapeAt, hs, Scope.Signature.ShapeTargets] using htgt
      subst hobs
      intro t ht; cases ht
  | topTargeted k =>
      simp only [hs] at h5
      obtain ⟨hek, -, he⟩ := h5
      have hobs : ∀ t ∈ obs, t.kind = k := by
        simpa [PrimSig.shapeAt, hs, Scope.Signature.ShapeTargets] using htgt
      intro t ht
      refine ⟨k, .top, hek, ?_, (Scope.Domain.Range.memK_top_iff k t).mpr (hobs t ht)⟩
      rw [PrimSig.inst_eff, he, Eff.instR_single]
      exact (Eff.mem_single _ _).mpr rfl
  | single k p =>
      simp only [hs] at h5
      obtain ⟨hek, hrk, he, o', hp, hvk⟩ := h5
      obtain ⟨R, rfl⟩ : ∃ R, rs = [R] := by
        have hlen := hR.length
        rw [PrimSig.nranges, hrk] at hlen
        match rs, hlen with
        | [R], _ => exact ⟨R, rfl⟩
      have hpi : ((s.inst [R]).params.map (Ty.subst ts es))[p]? = some (.opaque o' (.fixed R)) := by
        rw [List.getElem?_map, PrimSig.inst_params, List.getElem?_map, hp]
        simp [Ty.instTarget, Scope.Signature.Ix.inst, Ty.subst_opaque]
      obtain ⟨w, hwp, hwt⟩ := hw.lookup p hpi
      have hmemE : Eff.mem (s.inst [R]).eff (.name l (.fixed R)) := by
        rw [PrimSig.inst_eff, he, Eff.instR_singleAt]
        exact (Eff.mem_singleAt _ _ _).mpr rfl
      rcases hwt.canonical_opaque with ⟨n, rfl, hix⟩ | ⟨t0, R0, rfl, hix, hk0, hm0⟩ |
          ⟨t0, R0, c0, n0, rfl, hix, hk0, hm0, -, -⟩
      · cases hix
        have hobs : ∀ t ∈ obs, t.kind = k := by
          simpa [PrimSig.shapeAt, hs, hwp, Val.target?, Scope.Signature.ShapeTargets] using htgt
        intro t ht
        exact ⟨k, .top, hek, hmemE, (Scope.Domain.Range.memK_top_iff k t).mpr (hobs t ht)⟩
      · cases hix
        have hobs : obs = [t0] := by
          simpa [PrimSig.shapeAt, hs, hwp, Val.target?, Scope.Signature.ShapeTargets] using htgt
        subst hobs
        intro t ht
        rw [List.mem_singleton] at ht
        subst ht
        have hkind : t.kind = k := by
          rw [hvk] at hk0
          exact (Option.some.inj hk0).symm
        exact ⟨k, R, hek, hmemE, hkind, hm0⟩
      · cases hix
        have hobs : obs = [t0] := by
          simpa [PrimSig.shapeAt, hs, hwp, Val.target?, Scope.Signature.ShapeTargets] using htgt
        subst hobs
        intro t ht
        rw [List.mem_singleton] at ht
        subst ht
        have hkind : t.kind = k := by
          rw [hvk] at hk0
          exact (Option.some.inj hk0).symm
        exact ⟨k, R, hek, hmemE, hkind, hm0⟩

/-- 全体の信頼条件のもとでの同じ補題。 -/
theorem Builtins.Assumptions.obs_allowed (hA : B.Assumptions P)
    {Ψ : StoreTy} {b : PrimName} {s : PrimSig} {rs : List Scope.Domain.Range} {ts : List Ty} {es : List Eff}
    {ws : List Val} {o : Outcome} {obs : List Scope.Domain.Target}
    (hb : B.sig b = some s) (hk : s.kind = .io ∨ s.kind = .exit) (hR : B.RangeAdmissible b s rs)
    (htl : ts.length = s.ntys) (hel : es.length = s.neffs) (had : s.admits [] ts)
    (hw : HasTypeVs P B Ψ [] [] ws ((s.inst rs).params.map (Ty.subst ts es)))
    (hr : B.ioResponse b ts es ws o obs) :
    ∃ l, s.opEff = some l ∧ ∀ t ∈ obs, B.Allows (s.inst rs).eff l t :=
  Builtins.TargetAgreement.obs_allowed hA.core hA.target hb hk hR htl hel had hw hr

end Benitoite.Release
