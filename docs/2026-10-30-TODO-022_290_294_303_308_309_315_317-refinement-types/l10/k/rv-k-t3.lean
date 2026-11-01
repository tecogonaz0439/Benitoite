import Benitoite.Release.Refinement.LegacyValues
import Benitoite.Release.Refinement.LegacyTableFacts
/-! 欄を持つ構成子の表の正例と、保持値の node の正例・負例。 -/
namespace Benitoite.Release.Refinement.RVK3

noncomputable section

def someDecl : Benitoite.Release.ConDecl := ⟨"Option", 1, [.tvar 0]⟩
def K : DeclarationKinds := ⟨fun _ => .value, fun _ => [], fun _ _ => []⟩
def P0 : Benitoite.Release.Program := {
  defs := fun _ => none, cons := fun _ => some someDecl, ops := fun _ => none,
  effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }
def target : Scope.Domain.Target := .endpoint ⟨.name ["a"], 80⟩
def B0 (c : Option Benitoite.Release.Ty) : Benitoite.Release.Builtins := {
  sig := fun _ => none, delta := fun _ _ _ _ _ => none,
  ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
  isResource := fun _ => false, effects := fun _ => none,
  sat := fun _ _ _ => True, refGet := "get", refSet := "set",
  valKind := fun _ => some .endpoint, valContent := fun _ => c }
def B (c : Option Ty) : Builtins := {
  sig := fun _ => none, delta := fun _ _ _ _ _ => none,
  ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
  isResource := fun _ => false, effects := fun _ => none,
  sat := fun _ _ _ => True, refGet := "get", refSet := "set",
  valKind := fun _ => some .endpoint, valContent := fun _ => c }

theorem arity : (embedProgramWithKinds K P0).DataArity "Option" 1 := by
  refine ⟨⟨"Some", embedConDecl someDecl, rfl, rfl⟩, ?_⟩
  intro c cd hc _
  change some (embedConDecl someDecl) = some cd at hc
  cases hc; rfl

theorem tables : LegacyTables K P0 (B0 none) (B none) := by
  refine ⟨?_, ?_, rfl, rfl, rfl, rfl, rfl, rfl, ?_, ?_, ?_, ?_, ?_⟩
  · intro b s0 h; cases h
  · intro C a p; exact Iff.rfl
  · intro o; rfl
  · intro b rs; exact Iff.rfl
  · intro c cd c' cd' h h' _; cases h; cases h'; rfl
  · intro c cd h a ha
    cases h; simp only [someDecl, List.mem_singleton] at ha; subst a
    exact ⟨⟨Nat.zero_lt_succ 0, trivial, trivial⟩, rfl⟩
  · intro c cd h a ha
    cases h; simp only [someDecl, List.mem_singleton] at ha; subst a
    exact ⟨Nat.zero_lt_succ 0, trivial, trivial⟩

theorem con_scoped : (embedConDecl someDecl).Scoped (embedProgramWithKinds K P0) :=
  tables.constructor_scoped (c := "Some") rfl
theorem variance : (embedProgramWithKinds K P0).VarianceValid := tables.varianceValid

def store : Benitoite.Release.StoreTy := fun _ => none
def held : Benitoite.Release.Ty := .opaque "O" (.fixed .top)

theorem ctx : LegacyContextInput K P0 store [] [] ⟨[], [], 0, 0⟩ := by
  refine ⟨rfl, rfl, rfl, ?_, ?_⟩
  · intro l lt h; cases h
  · intro i a h; simp at h

theorem held_input : LegacyOutputInput K P0 (B0 none) (B none)
    (.value [] store Benitoite.Release.Qempty [] [] (.checked target) held) :=
  .node (.V_Checked (o := "O") (R := .top) (t := target) rfl trivial)
    ⟨ctx, ⟨"O", rfl, rfl, rfl⟩, ⟨"O", .top, rfl, rfl, rfl, rfl, rfl, trivial⟩,
      by intro a ha; simp only [List.mem_singleton] at ha; subst a; exact ⟨trivial, trivial, trivial, trivial, trivial⟩⟩
    (by simp)

/-- 保持内容を持つ型名の裸の checked は、旧の規則を通っても node の入力で拒む。 -/
theorem reject_content (T0 T) : ¬ LegacyOutputInput K P0 (B0 (some T0)) (B (some T))
    (.value [] store Benitoite.Release.Qempty [] [] (.checked target) held) := by
  intro h
  obtain ⟨o, r, _, _, _, hc, _⟩ := h.regular.2.2.1
  cases hc

theorem old_content (T0) : Benitoite.Release.HasTypeVQ P0 (B0 (some T0)) store Benitoite.Release.Qempty [] []
    (.checked target) held := .V_Checked (o := "O") (R := .top) (t := target) rfl trivial

#print axioms con_scoped
#print axioms variance
#print axioms held_input
#print axioms reject_content
end
end Benitoite.Release.Refinement.RVK3
