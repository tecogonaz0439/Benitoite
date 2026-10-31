import Lean
import Benitoite

/-! 多相節へ型付き像を移すための条件は、値の四保存則からは従わない。 -/
namespace Benitoite.Release.Refinement.HandlerContractBoundary
noncomputable section

def P : Program :=
  { defs := fun _ => none, cons := fun _ => none, ops := fun _ => none,
    effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }
def B : Builtins :=
  { sig := fun _ => none, delta := fun _ _ _ _ _ => none,
    ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => True,
    isResource := fun _ => false, effects := fun _ => none,
    sat := fun C _ _ => C = [], refGet := "get", refSet := "set" }

theorem value_conditions : Builtins.ValueAssumptions P B where
  sat_rename := by intros; assumption
  admits_rename := by intros; contradiction
  sat_values := by intros; assumption
  admits_values := by intros; contradiction

/-- 現在のCoreAssumptionsの全欄を満たす。四保存則だけの反例ではない。 -/
theorem core_conditions : Builtins.CoreAssumptions P B where
  toValueAssumptions := value_conditions
  external_typed := by intros; contradiction
  external_exists := by intros; contradiction
  external_no_targets := by intros; contradiction
  delta_typed := by intros; contradiction
  io_typed := by intros; contradiction
  io_kind := by intros; contradiction
  io_exists := by intros; contradiction
  pathBases_shape := by intros; contradiction
  opEff_io := by intros; contradiction
  effect_ops := by intros; contradiction
  store_shape := by intros; contradiction
  store_admits := by intros; contradiction

theorem integer_annotation (C : List TParam) (Γ : Ctx) :
    Ty.Annotation P C Γ (.base .integer) := by
  exact ⟨trivial, trivial, trivial⟩

theorem source_typed : HasTypeV P B StoreTy.empty [] [] [] (.setV []) (.set (.base .integer)) :=
  .V_Set .nil rfl (integer_annotation [] [])

/-- 同じ値は非空の型パラメータ文脈では、部分型を経ても一切型付かない。 -/
theorem target_untypable {Ψ Q C Γ Φ v a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hc : C ≠ []) (hv : v = .setV []) : False := by
  match h with
  | .V_Set _ hs _ => exact hc hs
  | .V_Sub h _ _ _ _ => exact target_untypable h hc hv
  | .V_Refine h _ _ _ _ _ _ _ => exact target_untypable h hc hv
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_Fun .. | .V_Prim .. | .V_Op ..
  | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern ..
  | .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError ..
  | .V_Map .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy ..
  | .V_Bytes .. | .V_Con .. | .V_Super .. | .V_List .. => cases hv
termination_by structural h

def sourceCtx : Ctx := [some (.set (.base .integer))]
def ν : Nat → Val := fun _ => .setV []

/-- Ctx.WFは次の群で導入する予約名なので、必要なスロットのWFを直接検査する。 -/
theorem source_context_wf :
    ∀ (i : Nat) (a : Ty), sourceCtx[i]? = some (some a) → a.WF 0 0 sourceCtx.length := by
  intro i a hi
  cases i with
  | zero =>
    simp only [sourceCtx, List.getElem?_cons_zero, Option.some.injEq] at hi
    cases hi
    exact trivial
  | succ i => simp [sourceCtx] at hi

theorem target_context_wf :
    ∀ (i : Nat) (a : Ty), ([] : Ctx)[i]? = some (some a) → a.WF 0 0 0 := by
  intro i a hi
  simp at hi

theorem source_subst_ok : SubstOk P B StoreTy.empty Qempty [] sourceCtx [] [] [] none ν := by
  intro i a hi
  cases i with
  | zero =>
    simp only [sourceCtx, List.getElem?_cons_zero, Option.some.injEq] at hi
    cases hi
    exact Or.inl ⟨(by intro b t e h; cases h), source_typed⟩
  | succ i => simp [sourceCtx] at hi

/-- setVの型引数の移動は値自体を変えない。型とRもこの例では不変である。 -/
theorem shape_unchanged : shiftTypes 1 0 (.set (.base .integer)) = .set (.base .integer) := rfl

theorem no_shifted_typed_image :
    ¬ HasTypeVQ P B StoreTy.empty Qempty [({} : TParam)] [] [] (.setV []) (.set (.base .integer)) :=
  fun h => target_untypable h (by simp) rfl

/-- 型パラメータを一つ加えた先で、同じ像のSubstOkは成立しない。 -/
theorem no_shifted_subst_ok :
    ¬ SubstOk P B StoreTy.empty Qempty [({} : TParam)] sourceCtx [] [] [] none ν := by
  intro h
  rcases h 0 (.set (.base .integer)) rfl with h | ⟨b,t,e,l,he,_⟩
  · exact no_shifted_typed_image h.2
  · cases he

namespace Open

def B : Builtins := { HandlerContractBoundary.B with
  sat := fun _ a p => p = ({} : TParam) ∨ a.norm.core = .tvar 0 }

theorem core_rename (a : Ty) (ξ : Nat → Nat) :
    (renameTy ξ a).core = renameTy ξ a.core := by
  cases a <;> try rfl
  case refined a p => exact core_rename a ξ

theorem zero_values {a : Ty} (h : a.norm.core = .tvar 0) (ν : Nat → Val) :
    (substTyValues ν a).norm.core = .tvar 0 := by
  change (a.rawBind (valEnv ν)).norm.norm.core = .tvar 0
  rw [Ty.norm_idem]
  simp only [valEnv, ← Ty.rawSubstV_eq_rawBind]
  rw [← Ty.norm_rawSubstV, Ty.core_norm, Ty.core_rawSubstV, h]
  rfl

theorem zero_rename {a : Ty} (h : a.norm.core = .tvar 0) (ξ : Nat → Nat) :
    (renameTy ξ a).norm.core = .tvar 0 := by
  change (Ty.rawBind (renEnv ξ) a).norm.core = .tvar 0
  rw [← Ty.norm_rawBind, Ty.core_norm]
  change ((renameTy ξ a.norm).core).norm = .tvar 0
  rw [core_rename, h]
  rfl

theorem value_conditions : Builtins.ValueAssumptions P B where
  sat_rename := by
    intro C Γ Δ a p ξ _ _ _ hs
    rcases hs with hs | hs
    · exact Or.inl hs
    · exact Or.inr (zero_rename hs ξ)
  admits_rename := by intros; contradiction
  sat_values := by
    intro Ψ Q C Γ Δ Ξ ν a p _ _ hs
    rcases hs with hs | hs
    · exact Or.inl hs
    · exact Or.inr (zero_values hs ν)
  admits_values := by intros; contradiction

theorem core_conditions : Builtins.CoreAssumptions P B where
  toValueAssumptions := value_conditions
  external_typed := by intros; contradiction
  external_exists := by intros; contradiction
  external_no_targets := by intros; contradiction
  delta_typed := by intros; contradiction
  io_typed := by intros; contradiction
  io_kind := by intros; contradiction
  io_exists := by intros; contradiction
  pathBases_shape := by intros; contradiction
  opEff_io := by intros; contradiction
  effect_ops := by intros; contradiction
  store_shape := by intros; contradiction
  store_admits := by intros; contradiction

/-- 旧sat_local相当の外側への延長も満たす。先頭への延長とは異なる。 -/
theorem sat_local (C1 C0 : List TParam) (a : Ty) (p : TParam) :
    B.sat C1 a p → B.sat (C1 ++ C0) a p := id

def element : Ty := .tvar 0
def value : Val := .setV []

theorem element_annotation : Ty.Annotation P [TParam.keyC] [] element :=
  ⟨(by change 0 < 1; omega), trivial, trivial⟩

theorem source_typed : HasTypeV P B StoreTy.empty [TParam.keyC] [] [] value (.set element) :=
  .V_Set .nil (Or.inr rfl) element_annotation

def setCore : Ty → Option Ty
  | .set a => some a
  | .refined a _ => setCore a
  | _ => none

theorem setCore_le {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) : setCore a = setCore b := by
  match h with
  | .refl => rfl
  | .trans h₁ h₂ => exact (setCore_le h₁).trans (setCore_le h₂)
  | .refine (a := a) (b := b) h _ _ _ =>
    change setCore a = setCore b
    exact setCore_le h
  | .forget | .introduce .. => rfl
  | .fn_effect .. | .list .. | .lazy .. | .map_value ..
  | .dependentFn .. | .scoped .. | .scoped_forget => rfl

/-- 空のSetでも、要素型のKey制約は型付き導出から取り出せる。 -/
theorem set_constraint {Ψ Q C Γ Φ v a} (h : HasTypeVQ P B Ψ Q C Γ Φ v a)
    (hv : v = value) : ∀ t, setCore a = some t → B.sat C t TParam.keyC := by
  match h with
  | .V_Set _ hs _ => intro t ht; cases ht; exact hs
  | .V_Sub h hl _ _ _ =>
    intro t ht
    exact set_constraint h hv t ((setCore_le hl).trans ht)
  | .V_Refine (a := a) h _ _ _ _ _ _ _ =>
    change ∀ t, setCore a = some t → _
    exact set_constraint h hv
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_Fun .. | .V_Prim .. | .V_Op ..
  | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern ..
  | .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError ..
  | .V_Map .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy ..
  | .V_Bytes .. | .V_Con .. | .V_Super .. | .V_List .. => cases hv
termination_by structural h

theorem shifted_element_rejected : ¬ B.sat [({} : TParam), TParam.keyC] (.tvar 1) TParam.keyC := by
  intro h
  rcases h with h | h
  · have he := congrArg TParam.key h
    cases he
  · cases h

theorem target_untypable :
    ¬ HasTypeV P B StoreTy.empty [({} : TParam), TParam.keyC] [] [] value
      (.set (shiftTypes 1 0 element)) := by
  intro h
  exact shifted_element_rejected (set_constraint h rfl _ rfl)

def sourceCtx : Ctx := [some (.set element)]
def shiftedCtx : Ctx := sourceCtx.map (Option.map (shiftTypes 1 0))
def ν : Nat → Val := fun _ => value

theorem source_subst_ok : SubstOk P B StoreTy.empty Qempty [TParam.keyC]
    sourceCtx [] [] [] none ν := by
  intro i a hi
  cases i with
  | zero =>
    simp only [sourceCtx, List.getElem?_cons_zero, Option.some.injEq] at hi
    cases hi
    exact Or.inl ⟨(by intro b t e h; cases h), source_typed⟩
  | succ i => simp [sourceCtx] at hi

theorem no_shifted_subst_ok : ¬ SubstOk P B StoreTy.empty Qempty
    [({} : TParam), TParam.keyC] shiftedCtx [] [] [] none ν := by
  intro h
  rcases h 0 (.set (.tvar 1)) rfl with h | ⟨b,t,e,l,he,_⟩
  · exact target_untypable h.2
  · cases he


end Open

end
end Benitoite.Release.Refinement.HandlerContractBoundary

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := env.constants.toList.filterMap fun (name, _) =>
    if (`Benitoite.Release.Refinement.HandlerContractBoundary).isPrefixOf name then some name else none
  let names := names.mergeSort (fun a b => a.toString < b.toString)
  logInfo m!"BOUNDARY_DECLARATIONS {names.length}"
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
