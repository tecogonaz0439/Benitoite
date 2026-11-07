import Benitoite.Release.Refinement.ScopeValueDelta
import Benitoite.Release.Refinement.ClosureTyping

/-!
# 明示拡大の範囲の列と行き先の一意性

設計書 01-12「Scope の組み込み」に対応する。明示拡大 `Scope.widenPathIn[R, S]` の範囲の列は、引数の型（元の範囲 R）と
戻り値の注釈（期待される型。行き先 S）から決まる（`widenRanges`）。具体化した署名の結果型は行き先の範囲そのものを持つ
ので、結果型が同じなら行き先は同じである（`widenPathIn_target_unique`）。
-/

namespace Benitoite.Release.Refinement
namespace ScopeWiden
open ScopeSignatures

/-- 明示拡大の範囲の列を、引数の型と戻り値の注釈から決める。どちらかが同じ名前の範囲付きの値型でなければ決まらない。 -/
def widenRanges : Ty → Ty → Option (List RangeExpr)
  | .opaque o (.fixed r), .opaque o' (.fixed s) => if o = o' then some [r, s] else none
  | _, _ => none

/-- 明示拡大の項目を範囲の列 `[r, s]` で具体化した署名は、`PathIn[r]` を受け取り `PathIn[s]` を返す純粋な関数である。 -/
theorem widenPathIn_instantiated (r s : RangeExpr) :
    instantiatedTel (Tel.instR [r, s] widenPathIn.tel) [] [] =
      Ty.toTel ["path"] [.opaque "Scope.PathIn" (.fixed r)] (.opaque "Scope.PathIn" (.fixed s)) Eff.empty := by
  have emptyRange : mapRangeAtoms (rangeAt 0 [r, s]) (fun _ => false) = (fun _ => false) := by
    funext x; cases x <;> simp [mapRangeAtoms]
  simp [emptyRange, widenPathIn, pureIn, PrimSig.tel, signatureTel,
    instantiatedTel, Tel.instR, Tel.substRAt, Tel.mapRanges, Tel.rawMapRanges,
    Ty.rawMapRanges, Eff.rawMapRanges, Tel.bind, Tel.rawBind, Ty.rawBind, Eff.rawBind,
    Tel.norm, Ty.norm, Ty.normTys, Ty.toTel, Ty.shiftV, Eff.shiftV, Eff.norm, Eff.empty,
    typeEnvAt, SubstEnv.up, substAtoms_nil, instAtoms_nil, rowFails,
    mapIx, rangeAt, RangeIx.inst]

/-- 具体化した署名の結果型は行き先の範囲 s を持つ。 -/
theorem widenPathIn_result (r s : RangeExpr) :
    (instantiatedTel (Tel.instR [r, s] widenPathIn.tel) [] []).result = .opaque "Scope.PathIn" (.fixed s) := by
  rw [widenPathIn_instantiated]
  simp [Ty.toTel, Tel.result, Ty.shiftV]

/-- 引数の型 `PathIn[r]` と戻り値の注釈 `PathIn[s]` から決めた範囲の列で具体化した署名は、同じ引数の型と結果型を持つ。 -/
theorem widenRanges_pathIn (r s : RangeExpr) :
    widenRanges (.opaque "Scope.PathIn" (.fixed r)) (.opaque "Scope.PathIn" (.fixed s)) = some [r, s] ∧
      instantiatedTel (Tel.instR [r, s] widenPathIn.tel) [] [] =
        Ty.toTel ["path"] [.opaque "Scope.PathIn" (.fixed r)] (.opaque "Scope.PathIn" (.fixed s)) Eff.empty :=
  ⟨by simp [widenRanges], widenPathIn_instantiated r s⟩

/-- 決めた範囲の列は、元の範囲と行き先の二つである。 -/
theorem widenRanges_spec {a b : Ty} {rs : List RangeExpr} (h : widenRanges a b = some rs) :
    ∃ o r s, a = .opaque o (.fixed r) ∧ b = .opaque o (.fixed s) ∧ rs = [r, s] := by
  unfold widenRanges at h
  split at h
  · split at h
    · rename_i o r o' s ho
      subst ho
      cases h
      exact ⟨o, r, s, rfl, rfl, rfl⟩
    · cases h
  · cases h

/-- 明示拡大の行き先は戻り値の注釈から一意に決まる。許容される列（長さ 2）で具体化した結果型が同じなら、行き先の範囲は
同じである。 -/
theorem widenPathIn_target_unique {rs rs' : List RangeExpr} (hl : rs.length = 2) (hl' : rs'.length = 2)
    (h : (instantiatedTel (Tel.instR rs widenPathIn.tel) [] []).result =
      (instantiatedTel (Tel.instR rs' widenPathIn.tel) [] []).result) : rs[1]? = rs'[1]? := by
  match rs, rs', hl, hl' with
  | [r, s], [r', s'], _, _ =>
    rw [widenPathIn_result, widenPathIn_result] at h
    simp only [Ty.opaque.injEq, RangeIx.fixed.injEq, true_and] at h
    simp [h]

end ScopeWiden
end Benitoite.Release.Refinement
