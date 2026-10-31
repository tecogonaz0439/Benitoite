import Benitoite.Release.TargetTable
import Benitoite.Release.Refinement.HeldValues

/-! # 保持内容についての標準表の並置

旧表の型を埋め込み、要求の型と内容なしの区分を同じ表から得る。
組込みの署名と応答条件の充足は別のモジュールで扱う。
-/
namespace Benitoite.Release.Refinement.TargetTable

def clientRequestTy : Ty := embedTy Benitoite.Release.TargetTable.clientRequestTy

def valContent (o : OpaqueName) : Option Ty :=
  (Benitoite.Release.TargetTable.valContent o).map embedTy

theorem request_content : valContent "Http.RequestIn" = some clientRequestTy := rfl

theorem path_content : valContent "Scope.PathIn" = none := rfl

end Benitoite.Release.Refinement.TargetTable
