import Benitoite.Release.Refinement.TypingDeclared
import Benitoite.Release.Refinement.ValueInstantiation
import Benitoite.Release.Refinement.Embedding

namespace Benitoite.Release.Refinement.ValueConstraintBoundary

/-- 外側の Integer を読む、整形式の鍵型。 -/
def keyTy : Ty := .refined (.base .integer) (.eq (.var 1) (.integer 0))
def sourceCtx : Ctx := [some (.base .integer)]
def zero : Val := .const (.integer ⟨0, by decide⟩)
def ν : Nat → Val := fun _ => zero

/-- 型の置換には不変だが、値注釈の置換には不変でない表の例。 -/
def Sat (_ : List TParam) (a : Ty) (p : TParam) : Prop := p.key = false ∨ a = keyTy

def B : Builtins :=
  { sig := fun _ => none
    delta := fun _ _ _ _ _ => none
    ioResponse := fun _ _ _ _ _ _ => False
    releaseResponse := fun _ _ => True
    isResource := fun _ => false
    effects := fun _ => none
    sat := Sat
    refGet := "get"
    refSet := "set" }

theorem source_annotation (P : Program) : Ty.Annotation P [] sourceCtx keyTy := by
  constructor
  · simp [keyTy, sourceCtx, Ty.WF, Pred.WF, Pred.VarsIn, Term.VarsIn, Ty.NotContCore, Ty.core]
  · simp [keyTy, sourceCtx, Ty.Sorted, Pred.Sorted, Term.HasSort, Term.Shape,
      Ty.HasSort, Ty.sort?, Term.References, Term.VarsIn, Ctx.Readable]
  · simp [keyTy, sourceCtx, Ty.Declared, Pred.Declared, Term.Declared, Ctx.declarationSelf,
      Ctx.extend, Ctx.Readable, Ty.shiftV]

theorem typed_image (P : Program) (Ψ : StoreTy) :
    SubstOk P B Ψ Qempty [] sourceCtx [] [] [] none ν := by
  intro i a hi
  cases i with
  | zero =>
    simp only [sourceCtx, List.getElem?_cons_zero, Option.some.injEq] at hi
    cases hi
    left
    exact ⟨by simp, .V_Const trivial⟩
  | succ i => simp [sourceCtx] at hi

theorem source_sat : B.sat [] keyTy TParam.keyC := Or.inr rfl

theorem substituted_key : substTyValues ν keyTy =
    .refined (.base .integer) (.eq (.integer 0) (.integer 0)) := by
  rfl

theorem target_not_sat : ¬ B.sat [] (substTyValues ν keyTy) TParam.keyC := by
  rw [substituted_key]
  simp [B, Sat, TParam.keyC, keyTy]

theorem shifted_not_sat : ¬ B.sat [] (keyTy.shiftV 1 0) TParam.keyC := by
  simp [B, Sat, TParam.keyC, keyTy, Ty.shiftV, predBind, termBind, termBind?]

/-- 既存の制約の型文脈の延長則より強い性質を満たす。 -/
theorem sat_local (C1 C0 : List TParam) (a : Ty) (p : TParam) :
    Sat C1 a p → Sat (C1 ++ C0) a p := id

/-- 制約なしのパラメータは全型を受け入れる。 -/
theorem sat_unconstrained (a : Ty) : Sat [] a ({} : TParam) := Or.inl rfl

theorem keyTy_type_subst (c : Nat) (ts : List Ty) (es : List Eff) :
    keyTy.substAt c ts es = keyTy := by
  simp [Ty.substAt, substTypeAt, Ty.bind, keyTy, Ty.rawBind, typeEnvAt,
    upValues_id, predBind_id, Ty.norm]

/-- 閉じた型の像に限らず、任意の型・行の像でも既存の型置換則を満たす。 -/
theorem sat_subst (C0 C1 : List TParam) (a : Ty) (p : TParam) (ts : List Ty) (es : List Eff) :
    Sat (C1 ++ C0) a p → Sat C1 (a.substAt C1.length ts es) p := by
  rintro (hp | rfl)
  · exact Or.inl hp
  · exact Or.inr (keyTy_type_subst _ _ _)

/-- 旧の sat の三つの条件だけから値置換の保存は導けない。 -/
theorem no_value_transport : ¬ (∀ (a : Ty) (p : TParam),
    B.sat [] a p → B.sat [] (substTyValues ν a) p) := by
  intro h
  exact target_not_sat (h _ _ source_sat)

/-- 署名どおりの空 Map の前提が、型付きの値置換後に失われる。 -/
theorem map_premises (P : Program) (Ψ : StoreTy) :
    HasTypeEachQ P B Ψ Qempty [] sourceCtx [] [] keyTy ∧
    Ty.Annotation P [] sourceCtx keyTy ∧ B.sat [] keyTy TParam.keyC ∧
    ¬ B.sat [] (substTyValues ν keyTy) TParam.keyC :=
  ⟨.nil, source_annotation P, source_sat, target_not_sat⟩

def locStore : StoreTy := fun i => if i = 0 then some (.ref (.base .unit)) else none

theorem locStore_wf : StoreTy.WF locStore := by
  intro i t ht
  by_cases hi : i = 0
  · simp only [locStore, hi, ↓reduceIte, Option.some.injEq] at ht
    cases ht; trivial
  · simp [locStore, hi] at ht

theorem location_typed (P : Program) :
    HasTypeVQ P B locStore Qempty [] [] [] (.loc 0) (.reference (.base .unit)) :=
  .V_LocRef (by simp [locStore]) trivial

private theorem empty_no_location_aux {P Ψ Q C Γ Φ v a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) : Ψ 0 = none → v = .loc 0 → False := by
  match h with
  | .V_LocRef hl _ | .V_LocLazy hl _ => intro h0 he; cases he; rw [h0] at hl; cases hl
  | .V_Sub hv _ _ _ _ => exact empty_no_location_aux hv
  | .V_Refine hv _ _ _ _ _ _ _ => exact empty_no_location_aux hv
  | .V_Var _ _ | .V_Const _ | .V_Lam _ _ _ _ _ | .V_List _ _ _ _
  | .V_Fun _ _ _ _ | .V_Prim _ _ _ _ _ | .V_Op _ _ _ _
  | .V_Map _ _ _ _ _ _ | .V_Set _ _ _ | .V_Dict _ _ _ _ _ _ _ _
  | .V_PathBases _ | .V_ScopePattern _ _ _ | .V_Checked _ _ _ |
      .V_CheckedRequest _ _ _ _ _ _ | .V_CheckedAt _ | .V_AtError _ _
  | .V_ExternalRef _ _ _ _ | .V_ExternalHandle _ _ _ _ _ _ _
  | .V_Raise _ | .V_Bytes _ | .V_Con _ _ _ _ _ _ | .V_Super _ _ _ _ => intro _ he; cases he

theorem empty_no_location {P Q C Γ Φ a}
    (h : HasTypeVQ P B StoreTy.empty Q C Γ Φ (.loc 0) a) : False :=
  empty_no_location_aux h rfl rfl

theorem cannot_erase_location : ¬ StoreTy.PreservesNormals locStore StoreTy.empty := by
  intro h
  have hh := h 0 (.ref (.base .unit)) (by simp [locStore]) trivial
  cases hh

/-- 表の保存条件を要求すると、外側の番号を区別する反例の表は除かれる。 -/
theorem bad_table_excluded (P : Program) : ¬ Builtins.ValueAssumptions P B := by
  intro h
  apply target_not_sat
  apply h.sat_values StoreTy.empty Qempty [] sourceCtx [] [] ν keyTy TParam.keyC
  · intro i a hi ho
    cases i with
    | zero => simp only [sourceCtx, List.getElem?_cons_zero, Option.some.injEq] at hi; cases hi; exact .V_Const trivial
    | succ i => simp [sourceCtx] at hi
  · exact source_annotation P
  · exact source_sat

theorem bad_core_excluded (P : Program) : ¬ Builtins.CoreAssumptions P B :=
  fun h => bad_table_excluded P h.values

def goodB : Builtins := { B with sat := fun _ _ _ => True }

theorem good_conditions (P : Program) : Builtins.ValueAssumptions P goodB := by
  constructor
  · intros; trivial
  · intro b sg C Γ Δ ts ξ hb; cases hb
  · intros; trivial
  · intro b sg Ψ Q C Γ Δ Ξ ν ts hb; cases hb

theorem base_annotation (P : Program) (Γ : Ctx) (b : BaseTy) : Ty.Annotation P [] Γ (.base b) :=
  ⟨trivial, trivial, trivial⟩

def duplicateMap : Val := .mapV [zero, zero] [.const .unit, .const .unit]

theorem duplicate_map_typed (P : Program) :
    HasTypeVQ P goodB StoreTy.empty Qempty [] [] [] duplicateMap (.map (.base .integer) (.base .unit)) :=
  .V_Map (.cons (.V_Const trivial) (.cons (.V_Const trivial) .nil))
    (.cons (.V_Const trivial) (.cons (.V_Const trivial) .nil)) rfl trivial
    (base_annotation P [] _) (base_annotation P [] _)

theorem dependent_map_typed (P : Program) :
    HasTypeVQ P goodB StoreTy.empty Qempty [] sourceCtx [] (.mapV [] []) (.map keyTy (.base .unit)) :=
  .V_Map .nil .nil rfl trivial (source_annotation P) (base_annotation P sourceCtx _)

theorem good_images (P : Program) :
    SubstOk P goodB StoreTy.empty Qempty [] sourceCtx [] [] [] none ν := by
  intro i a hi
  cases i with
  | zero => simp only [sourceCtx, List.getElem?_cons_zero, Option.some.injEq] at hi; cases hi
            exact Or.inl ⟨by simp, .V_Const trivial⟩
  | succ i => simp [sourceCtx] at hi

theorem dependent_map_substituted (P : Program) :
    HasTypeVQ P goodB StoreTy.empty Qempty [] [] []
      (Val.subst ν (.mapV [] [])) (substTyValues ν (.map keyTy (.base .unit))) :=
  (dependent_map_typed P).subst (good_conditions P) StoreTy.WF.empty (good_images P) (by simp)

def badSig : PrimSig :=
  { tparams := [⟨{}, .value⟩], neffs := 0, names := [], params := [], ret := .base .unit,
    eff := Eff.empty, admits := fun _ ts => ts = [keyTy], kind := .pure, opEff := none }
def admitsB : Builtins := { goodB with sig := fun _ => some badSig }

theorem bad_admits_excluded (P : Program) : ¬ Builtins.ValueAssumptions P admitsB := by
  intro h
  have hh := h.admits_values "bad" badSig StoreTy.empty Qempty [] sourceCtx [] [] ν [keyTy] rfl
    (by intro i a hi ho
        cases i with
        | zero => simp only [sourceCtx, List.getElem?_cons_zero, Option.some.injEq] at hi; cases hi; exact .V_Const trivial
        | succ i => simp [sourceCtx] at hi)
    (by intro t ht; simp only [List.mem_singleton] at ht; subst t; exact source_annotation P) rfl
  change [substTyValues ν keyTy] = [keyTy] at hh
  have he := List.cons.inj hh
  rw [substituted_key] at he
  cases he.1

/-- letの本体が、呼出し前からあった値を同じ番号で参照する。 -/
theorem let_capture_preserved (P : Program) (σ : PathEnv) :
    step P goodB σ (fun _ _ _ _ => (.err "unused", [])) (fun _ _ _ => (.err "unused", []))
      (fun _ => none) (fun _ => 0)
      (.run (.mk (.mk [some (.const .unit)]) (.letIn (.ret zero) (.ret (.var 1)))) [] Store.empty) =
    some (none, .run (.mk (.mk [some (.const .unit)]) (.ret zero))
      [.letF (.mk (.mk [some (.const .unit)]) (.ret (.var 1)))] Store.empty) := rfl

theorem let_bind_once (P : Program) (σ : PathEnv) :
    step P goodB σ (fun _ _ _ _ => (.err "unused", [])) (fun _ _ _ => (.err "unused", []))
      (fun _ => none) (fun _ => 0)
      (.run (.pure (.ret zero)) [.letF (.mk (.mk [some (.const .unit)]) (.ret (.var 1)))] Store.empty) =
    some (none, .run (.mk (.mk [some zero, some (.const .unit)]) (.ret (.var 1))) [] Store.empty) := rfl

theorem captured_outer_after_application (P : Program) (σ : PathEnv) :
    Step P goodB σ
      (.run (.mk (.mk [some (.closure (.param "x" (.base .integer) (.done (.base .unit) Eff.empty))
        (.mk (.mk [some (.const .unit)]) (.ret (.var 1))))]) (.app (.var 0) [zero])) [] Store.empty)
      none (.run (.mk (.mk [some zero, some (.const .unit)]) (.ret (.var 1))) [.mark] Store.empty) :=
  Step.E_Lam (signature := .param "x" (.base .integer) (.done (.base .unit) Eff.empty))
    (body := .mk (.mk [some (.const .unit)]) (.ret (.var 1))) (ws := [zero]) rfl rfl

theorem captured_body_view :
    (Closure.mk (.mk [some zero, some (.const .unit)]) (.ret (.var 1))).view = .ret (.const .unit) := rfl

#print axioms locStore_wf
#print axioms location_typed
#print axioms empty_no_location
#print axioms cannot_erase_location
#print axioms sat_local
#print axioms sat_unconstrained
#print axioms keyTy_type_subst
#print axioms source_sat
#print axioms substituted_key
#print axioms empty_no_location_aux
#print axioms source_annotation
#print axioms typed_image
#print axioms target_not_sat
#print axioms shifted_not_sat
#print axioms sat_subst
#print axioms no_value_transport
#print axioms map_premises
#print axioms bad_table_excluded
#print axioms bad_core_excluded
#print axioms good_conditions
#print axioms base_annotation
#print axioms duplicate_map_typed
#print axioms dependent_map_typed
#print axioms good_images
#print axioms dependent_map_substituted
#print axioms bad_admits_excluded
#print axioms let_capture_preserved
#print axioms let_bind_once
#print axioms captured_outer_after_application
#print axioms captured_body_view
end Benitoite.Release.Refinement.ValueConstraintBoundary
