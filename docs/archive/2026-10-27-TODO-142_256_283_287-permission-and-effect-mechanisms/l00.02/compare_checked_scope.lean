import Benitoite.Checked.Scope
import Benitoite.Scope.Domain

/-! L00.02 の照合: 既存の Checked.Scope の分類と Domain の分類の対応（リポジトリの外の一時ファイル）。 -/
namespace L0002Compare
open Benitoite

def nameOf : Checked.Scope.HostPattern → Scope.Domain.NamePattern
  | .exact s => .exact s
  | .one s => .one s
  | .many s => .many s

def pathOf : Checked.Scope.PathPattern → Scope.Domain.PathPattern
  | .exact s => .exact s
  | .tree s => .tree s

theorem host_matches (p : Checked.Scope.HostPattern) (h : List String) :
    Checked.Scope.HostMatches p h ↔ (nameOf p).Matches h := by
  cases p <;> rfl

theorem path_matches (p : Checked.Scope.PathPattern) (w : List String) :
    Checked.Scope.PathMatches p w ↔ (pathOf p).Matches w := by
  cases p <;> rfl

theorem host_word_wf (w : List String) :
    Checked.Scope.ValidHostWord w ↔ Scope.Domain.NameWordWF w := Iff.rfl

theorem host_pattern_wf (p : Checked.Scope.HostPattern) :
    Checked.Scope.ValidHostPattern p ↔ (nameOf p).WF := by
  cases p <;> rfl

theorem path_word_wf (w : List String) :
    Checked.Scope.ValidPathWord w ↔ Scope.Domain.PathWordWF w := Iff.rfl

theorem path_pattern_wf (p : Checked.Scope.PathPattern) :
    Checked.Scope.ValidPathPattern p ↔ (pathOf p).WF := by
  cases p <;> rfl

theorem port_valid (i : Int) :
    Checked.Scope.ValidPort i ↔ (Scope.Domain.Port.ofInt? i).isSome := by
  rw [Scope.Domain.Port.ofInt?_isSome_iff]; rfl

end L0002Compare
