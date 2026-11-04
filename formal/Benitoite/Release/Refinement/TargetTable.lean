import Benitoite.Release.TargetTable
import Benitoite.Release.Refinement.HeldValues

/-! # 保持内容についての標準表の並置

Release.TargetTable の型を埋め込み、要求の型と内容なしの区分を同じ表から得る。
組込みの署名と応答条件の充足は別のモジュールで扱う。
-/
namespace Benitoite.Release.Refinement.TargetTable

def clientRequestTy : Ty := embedTy Benitoite.Release.TargetTable.clientRequestTy

def valContent (o : OpaqueName) : Option Ty :=
  (Benitoite.Release.TargetTable.valContent o).map embedTy

theorem request_content : valContent "Http.RequestIn" = some clientRequestTy := rfl

theorem path_content : valContent "Scope.PathIn" = none := rfl

theorem content_rows {name a} (h : valContent name = some a) : a.RowsIn (· < 0) := by
  simp only [valContent, Benitoite.Release.TargetTable.valContent] at h
  split at h
  · cases Option.some.inj h
    trivial
  · cases h

/-- 範囲を持つ標準の値型だけに対象の種類を登録する。 -/
def valKind : OpaqueName → Option Scope.Domain.Kind
  | "Scope.PathIn" => some .path
  | "Http.RequestIn" => some .endpoint
  | _ => none

example : valKind "Scope.PathIn" = some .path ∧ valContent "Scope.PathIn" = none ∧
    valKind "Http.RequestIn" = some .endpoint ∧
    valContent "Http.RequestIn" = some clientRequestTy := ⟨rfl,rfl,rfl,rfl⟩

end Benitoite.Release.Refinement.TargetTable
