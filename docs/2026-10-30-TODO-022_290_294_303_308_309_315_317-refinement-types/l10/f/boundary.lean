import Lean
import Benitoite

/-! 旧宣言の辞書の入力を、実際の lookup と受理・拒否で検査する。 -/
namespace Benitoite.Release.Refinement.L10FBoundary
noncomputable section

def K : DeclarationKinds := ⟨fun _ => .value, fun _ => [], fun _ _ => []⟩
def B0 : Benitoite.Release.Builtins := {
  sig := fun _ => none, delta := fun _ _ _ _ _ => none,
  ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
  isResource := fun _ => false, effects := fun _ => none,
  sat := fun _ _ _ => True, refGet := "get", refSet := "set" }
def B : Builtins := {
  sig := fun _ => none, delta := fun _ _ _ _ _ => none,
  ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
  isResource := fun _ => false, effects := fun _ => none,
  sat := fun _ _ _ => True, refGet := "get", refSet := "set" }
def cd : Benitoite.Release.ClassDecl := ⟨[], fun _ => none⟩

def goodOp : Benitoite.Release.OpDecl :=
  { eff := "E", tparams := [{}], names := ["d"], params := [.dict "C" (.tvar 0)],
    ret := .base .unit, dictParams := [("C", 0)] }
-- rv-f-t3 の oldOp と同じデータ。原本は import も編集もしない。
def badOp : Benitoite.Release.OpDecl :=
  { eff := "E", tparams := [{}], names := ["x"], params := [.base .unit],
    ret := .base .unit, dictParams := [("C", 0)] }
def badIndex : Benitoite.Release.OpDecl :=
  { goodOp with dictParams := [("C", 1)] }

def opProgram (od : Benitoite.Release.OpDecl) : Benitoite.Release.Program := {
  defs := fun _ => none, cons := fun _ => none, ops := fun _ => some od,
  effects := fun _ => none, classes := fun _ => some cd, impls := fun _ => none }

theorem reject_bad_head : ¬ LegacyDeclarationsInput K (opProgram badOp) B0 B := by
  intro h
  have same := (h.op_dictionaryInputs (o := "o") rfl).2
  simp [badOp, embedOpDecl, embedParameters, embedTy, Ty.shiftV_zero] at same

theorem reject_bad_index : ¬ LegacyDeclarationsInput K (opProgram badIndex) B0 B := by
  intro h
  have bound := (h.op_dictionaryInputs (o := "o") rfl).1 ("C", 1) (by simp [badIndex])
  simp [badIndex, goodOp] at bound

theorem good_source : LegacyTypeInput K (opProgram goodOp)
    ⟨[.value], [{}], 0, 0⟩
    (.fn goodOp.names goodOp.params goodOp.ret (Benitoite.Release.Eff.single goodOp.eff)) .value := by
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · refine ⟨?_, ?_, trivial, trivial⟩
    · simp [NamesWF, goodOp, embedTy]
    · exact ⟨⟨embedClassDeclWithKinds K "C" cd, rfl, rfl⟩, trivial⟩
  · refine ⟨?_, ⟨by change 0 < 1; decide, trivial⟩, trivial, trivial, ?_⟩
    · simp [NamesWF, goodOp, embedTy]
    · exact embed_canonical rfl
  · exact ⟨⟨trivial, trivial⟩, trivial, trivial⟩
  · exact ⟨⟨trivial, trivial⟩, trivial, trivial⟩
  · refine ⟨⟨trivial, trivial⟩, trivial, ?_, trivial⟩
    intro name ix hi
    cases ix with
    | fixed _ => trivial
    | rvar i => simp [embedAtoms, Atom.toOld?] at hi

theorem good_declarations : LegacyDeclarationsInput K (opProgram goodOp) B0 B := by
  refine ⟨?_, ?_, ?_, ?_⟩
  · intro _ _ h; cases h
  · intro _ od h
    cases h
    exact ⟨good_source, by simp [goodOp], by simp [goodOp, embedOpDecl, embedParameters,
      embedTy, Ty.shiftV_zero]⟩
  · intro _ _ _ _ h hm
    cases h
    cases hm
  · intro _ _ h; cases h

theorem good_op_inputs :
    (∀ p ∈ goodOp.dictParams, p.2 < goodOp.tparams.length) ∧
    (embedOpDecl goodOp).params.take goodOp.dictParams.length =
      goodOp.dictParams.map (fun p => Ty.dict p.1 (.tvar p.2)) :=
  good_declarations.op_dictionaryInputs (o := "o") rfl

def impl : Benitoite.Release.ImplDecl :=
  ⟨[{}], [("C", 0)], "C", .base .unit, fun _ => none, fun _ => none⟩
def implProgram (present : Bool) : Benitoite.Release.Program := {
  defs := fun _ => none, cons := fun _ => none, ops := fun _ => none,
  effects := fun _ => none, classes := fun _ => if present then some cd else none,
  impls := fun _ => some impl }

theorem good_impl_declarations : LegacyDeclarationsInput K (implProgram true) B0 B := by
  refine ⟨?_, ?_, ?_, ?_⟩
  · intro _ _ h; cases h
  · intro _ _ h; cases h
  · intro _ _ _ _ h hm
    cases h
    cases hm
  · intro _ id h
    cases h
    refine ⟨⟨trivial, trivial, trivial, trivial, trivial⟩, ?_, ?_, ?_⟩
    · intro a ha
      simp only [Benitoite.Release.ImplDecl.dictTys, impl, List.map_cons, List.map_nil,
        List.mem_singleton] at ha
      subst a
      exact ⟨⟨embedClassDeclWithKinds K "C" cd, rfl, rfl⟩, by change 0 < 1; decide, trivial, trivial, trivial⟩
    · intro _ _ h; cases h
    · intro _ _ _ _ _ _ h; cases h

theorem impl_kind_supplied :
    ∀ a ∈ (embedImplDecl impl).dictTys,
      a.HasKind (embedProgramWithKinds K (implProgram true)) [.value] .value :=
  good_impl_declarations.impl_dictionaryKinds (i := "i") rfl

theorem impl_missing_class_rejected : ¬ LegacyDeclarationsInput K (implProgram false) B0 B := by
  intro h
  have hk := h.impl_dictionaryKinds (i := "i") rfl (.dict "C" (.tvar 0)) (by simp [impl, embedImplDecl, ImplDecl.dictTys])
  obtain ⟨cl, lookup, _⟩ := hk
  cases lookup

end
end Benitoite.Release.Refinement.L10FBoundary

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if env.getModuleIdxFor? name == none && name.toString.contains "L10FBoundary" then some name else none).mergeSort
      (fun a b => a.toString < b.toString)
  logInfo m!"BOUNDARY_CONSTANTS {names.length}"
  for name in names do elabCommand (← `(#print axioms $(mkIdent name)))
