import Lean
import Benitoite.Release.Refinement.Canonical
import Benitoite.Release.Refinement.SubstitutionContracts
import Benitoite.Release.Refinement.TypeShiftContext
import Benitoite.Release.Refinement.TypeShiftTyping

/-! 制約の読み手を正規形に揃えると、元の入力で移動の保存が成立する。 -/
namespace Benitoite.Release.Refinement.TypeShiftCounter
noncomputable section
abbrev U : Ty := .base .unit
abbrev raw : Ty := .refined U .truth

def od : OpDecl := ⟨"E", [{ equality := true }], [], [], U, []⟩
def prog : Program :=
  { defs := fun _ => none, cons := fun _ => none, ops := fun _ => some od,
    effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }
def builtins : Builtins :=
  { sig := fun _ => none, delta := fun _ _ _ _ _ => none,
    ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
    isResource := fun _ => false, effects := fun _ => none,
    sat := fun C a _ => C = [] ∨ a.Normal, refGet := "get", refSet := "set" }

theorem assumptions : Builtins.TypeAssumptions prog builtins := by
  constructor
  · intros; exact Or.inr (Ty.norm_idem _)
  · intro b sg C C' Γ Δ ts ρ hl; cases hl
  · intros; exact Or.inr (Ty.norm_idem _)
  · intro b sg C0 C1 ts ts' es hl; cases hl

theorem raw_annotation (C : List TParam) : Ty.Annotation prog C [] raw := by
  refine ⟨?_, ?_, ?_⟩
  · simp [raw, U, Ty.WF, Pred.WF, Pred.VarsIn, Ty.NotContCore]
  · trivial
  · trivial

theorem raw_not_normal : ¬ raw.Normal := by intro h; cases h

theorem original_sat : builtins.sat [] raw {} := Or.inl rfl

theorem shifted_unsat : ¬ builtins.sat [{}] (shiftTypes 1 0 raw) {} := by
  change ¬ (([{}] : List TParam) = [] ∨ raw.Normal)
  rintro (h | h)
  · cases h
  · exact raw_not_normal h

theorem sat_local_raw_counterexample :
    Builtins.TypeAssumptions prog builtins ∧ Ty.Annotation prog [] [] raw ∧
    Ty.Annotation prog [{}] [] raw ∧ builtins.sat [] raw {} ∧
    ¬ builtins.sat [{}] raw {} :=
  ⟨assumptions, raw_annotation [], raw_annotation [{}], original_sat, shifted_unsat⟩

def sg : PrimSig :=
  { tparams := [], neffs := 0, names := [], params := [], ret := U, eff := Eff.empty,
    admits := fun C ts => C = [] ∨ ∀ a ∈ ts, a.Normal, kind := .pure, opEff := none }
def admitsBuiltins : Builtins := { builtins with sig := fun _ => some sg }

theorem admits_assumptions : Builtins.TypeAssumptions prog admitsBuiltins := by
  constructor
  · intros; exact Or.inr (Ty.norm_idem _)
  · intro b s C C' Γ Δ ts ρ hl hr ha hb hs
    cases Option.some.inj hl
    right
    intro a hm
    obtain ⟨x, hx, rfl⟩ := List.mem_map.mp hm
    exact Ty.norm_idem _
  · intros; exact Or.inr (Ty.norm_idem _)
  · intro b s C0 C1 ts ts' es hl hs hw ht hn
    cases Option.some.inj hl
    right
    intro a hm
    obtain ⟨x, hx, rfl⟩ := List.mem_map.mp hm
    exact Ty.norm_idem _

theorem admits_local_raw_counterexample :
    Builtins.TypeAssumptions prog admitsBuiltins ∧ admitsBuiltins.sig "b" = some sg ∧
    TypeAnnotations prog [] [] [raw] ∧ TypeAnnotations prog [{}] [] [raw] ∧
    sg.admits [] [raw] ∧ ¬ sg.admits [{}] [raw] := by
  refine ⟨admits_assumptions, rfl, ?_, ?_, Or.inl rfl, ?_⟩
  · intro a ha; cases List.mem_singleton.mp ha; exact raw_annotation []
  · intro a ha; cases List.mem_singleton.mp ha; exact raw_annotation [{}]
  · rintro (he | hn)
    · cases he
    · exact raw_not_normal (hn raw (by simp))

abbrev result : Ty := .dependentFn (instantiatedTel od.tel [raw] [])

theorem original_typed : HasTypeVQ prog builtins StoreTy.empty Qempty [] [] []
    (.op "op" [raw]) result := by
  apply HasTypeVQ.V_Op (od := od) rfl
  · exact ⟨rfl, by change ([] : List String).Nodup; exact List.nodup_nil⟩
  · refine ⟨rfl, ?_⟩
    intro i a p hi hp
    cases i with
    | zero => cases Option.some.inj hi; exact Or.inl rfl
    | succ i => simp at hi
  · constructor
    · simp [od, OpDecl.tel, signatureTel, Ty.WF, Tel.WF, U, Eff.WF, Ty.WFList,
        Eff.Canonical, Eff.norm, Ty.normTys, Order.sortUnique]
    · intro a ha; cases List.mem_singleton.mp ha; exact raw_annotation []
    · refine ⟨rfl, [], rfl, ?_⟩
      intro i a k hi hk
      cases i with
      | zero => cases Option.some.inj hi; cases Option.some.inj hk
                simp [raw, U, Ty.HasKind, Ty.NotContCore]
      | succ i => simp at hi
    · intro e he; cases he
    · constructor <;> simp [instantiatedTel, od, OpDecl.tel, signatureTel, Tel.bind, Tel.rawBind,
        Tel.norm, Ty.rawBind, Ty.norm, U, Eff.rawBind, typeEnvAt, Eff.norm,
        rawBindTys, rowFails, Ty.normTys, Order.sortUnique, Ty.WF, Tel.WF,
        Eff.WF, Ty.WFList, Eff.Canonical, Ty.Sorted, Tel.Sorted, sortedEff, sortedTys,
        Ty.Declared, Tel.Declared, declaredEff, declaredTys]

theorem context_renaming : TypeParamRenaming [] [{}] (shiftIndex 1 0) := by
  intro i p hi; simp at hi

theorem context_map : TypeCtxMap 1 0 [] [] := by
  refine ⟨rfl, ?_⟩
  intro i a hi; simp at hi

/-- 生の項の型引数を保ったまま、構成した元の導出を主定理で移動する。 -/
theorem shifted_typed : HasTypeVQ prog builtins StoreTy.empty Qempty [{}] [] []
    ((Val.op "op" [raw]).shiftEAt 1 0) (shiftTypes 1 0 result) :=
  original_typed.shift_types assumptions StoreTy.WF.empty context_renaming rfl context_map

theorem full_shift_types_preserved :
    HasTypeVQ prog builtins StoreTy.empty Qempty [] [] [] (.op "op" [raw]) result ∧
    Builtins.TypeAssumptions prog builtins ∧ StoreTy.WF StoreTy.empty ∧
    TypeParamRenaming [] [{}] (shiftIndex 1 0) ∧
    ([{}] : List TParam).length = ([] : List TParam).length + 1 ∧
    TypeCtxMap 1 0 [] [] ∧
    HasTypeVQ prog builtins StoreTy.empty Qempty [{}] [] []
      ((Val.op "op" [raw]).shiftEAt 1 0) (shiftTypes 1 0 result) :=
  ⟨original_typed,assumptions,StoreTy.WF.empty,context_renaming,rfl,context_map,shifted_typed⟩

theorem truth_constraint_same (B : Builtins) (C : List TParam) (p : TParam) :
    B.sat C raw.norm p ↔ B.sat C U.norm p := Iff.rfl

theorem retained_predicate_distinct : (Ty.refined U .falsity).norm ≠ U.norm := by
  intro he; cases he

end
end Benitoite.Release.Refinement.TypeShiftCounter

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if (name.toString.splitOn ".TypeShiftCounter.").length > 1 then some name else none).mergeSort
      (fun a b => a.toString < b.toString)
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
