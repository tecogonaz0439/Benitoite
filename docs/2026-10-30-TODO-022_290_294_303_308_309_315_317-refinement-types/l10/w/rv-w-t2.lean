import Lean
import Benitoite.Release.Refinement.ProgramWellFormed

/-! 本番の二つの入口に、非空の表と条件を壊す入力を渡す。 -/
namespace Benitoite.Release.Refinement.RVWMut
open Benitoite.Release.Refinement
noncomputable section

def unit : Ty := .base .unit
def box : ConDecl := ⟨"Box", 1, [.tvar 0]⟩
def info : DataVarianceDecl := ⟨1, [.covariant], [unit], [(.positive, .tvar 0)]⟩
def identity : Def := ⟨[], 0, ["x"], [unit], unit, Eff.empty, .escape (.var 0)⟩
-- 自身の型パラメータは0、クラス引数は1である。
def method : MethSig := ⟨[⟨({} : TParam), .value⟩], 0, ["x"], [.tvar 1], .tvar 1, Eff.empty⟩
def parent : ClassDecl := ⟨.value, [], fun _ => none⟩
def klass : ClassDecl := ⟨.value, ["Parent"], fun m => if m = "id" then some method else none⟩
def implDecl : ImplDecl := ⟨[({} : TParam)], [("Parent", 0)], "Class", .tvar 0,
  fun s => if s = "Parent" then some (.var 0) else none,
  fun m => if m = "id" then some (.ret (.var 0)) else none⟩
def operation : OpDecl := ⟨"Effect", [], ["x"], [unit], unit, []⟩
def externalEntry : ExternalKey × ExternalDecl :=
  (.type (.mk 0), .type ⟨.mk 0, .mk 0, "Handle", 0, 0⟩)
def program : Program := {
  defs := fun f => if f = "identity" then some identity else none
  cons := fun c => if c = "Box.Box" then some box else none
  ops := fun o => if o = "Effect.op" then some operation else none
  effects := fun e => if e = "Effect" then some ["Effect.op"] else none
  classes := fun c => if c = "Class" then some klass else if c = "Parent" then some parent else none
  impls := fun i => if i = "Instance" then some implDecl else none
  externals := [externalEntry]
  dataInfo := fun d => if d = "Box" then some info else none }

variable (B : Builtins)

theorem annotation_unit (P : Program) (C : List TParam) (Γ : Ctx) : Ty.Annotation P C Γ unit := by
  constructor <;> trivial
theorem annotation_tvar (P : Program) (C : List TParam) (Γ : Ctx) (i : Nat) (h : i < C.length) :
    Ty.Annotation P C Γ (.tvar i) := ⟨h, trivial, trivial⟩

@[simp] theorem annotation_iff (P : Program) (C : List TParam) (Γ : Ctx) (a : Ty) :
    Ty.Annotation P C Γ a ↔ a.WF 0 C.length Γ.length ∧ a.Sorted Γ ∧ a.Declared P C Γ :=
  ⟨fun h => ⟨h.wf, h.sorted, h.declared⟩, fun h => ⟨h.1, h.2.1, h.2.2⟩⟩

theorem variance : program.VarianceValid := by
  constructor
  · intro d inf h
    simp only [program] at h
    split at h <;> simp_all only [Option.some.injEq, reduceCtorEq]
    subst inf
    refine ⟨rfl, ?_, ?_, ?_⟩
    · intro i v hv hn
      cases i with
      | succ i => simp [info] at hv
      | zero =>
        simp only [info, List.getElem?_cons_zero, Option.some.injEq] at hv
        subst v
        exact False.elim (hn ⟨"Box.Box", box, .tvar 0, by simp [program], rfl, by simp [box], by trivial⟩)
    · intro a ha
      simp only [info, List.mem_singleton] at ha
      subst a; trivial
    · intro item hi
      simp only [info, List.mem_singleton] at hi
      subst item
      exact ⟨.covariant, rfl, trivial⟩
  · intro c cd hc
    simp only [program] at hc
    split at hc <;> simp_all only [Option.some.injEq, reduceCtorEq]
    subst cd
    constructor
    · intro inf hi
      have he : inf = info := by simpa [program, box] using hi.symm
      subst inf; rfl
    · intro a ha
      simp only [box, List.mem_singleton] at ha
      subst a
      refine ⟨annotation_tvar _ _ _ _ (by simp [box]), ?_, ?_⟩
      · rfl
      · refine ⟨.covariant, ?_, trivial⟩
        simp [Program.varianceFor, program, info, box]

theorem external : program.ExternalWF := by
  constructor
  · simp [program]
  · intro key decl h
    simp only [program, List.mem_singleton] at h
    cases h
    exact ⟨rfl, rfl⟩

theorem def_typed : identity.WellTyped program B := by
  refine ⟨by simp [NamesWF, identity], ?_, ?_, .param (.done (.C_Escape (.V_Var rfl ?_) (annotation_unit _ _ _)))⟩
  · exact ⟨trivial, trivial, trivial⟩
  · constructor <;> simp [Ty.WF, Tel.WF, Eff.WF, Ty.WFList, Eff.Canonical, Eff.empty, Eff.norm, Ty.normTys, Ty.Sorted, Tel.Sorted, sortedEff, sortedTys, Ty.Declared, Tel.Declared, declaredEff, declaredTys, identity, Def.tel, signatureTel, unit]
  · intro b t e h; cases h

-- 型の置換と、実装の辞書の位置を空ける値の移動をそれぞれ使う。
theorem method_contract :
    Tel.shiftV implDecl.dictTys.length 0
      (Tel.bind (typeEnvAt method.tparams.length [implDecl.target] []) method.tel) =
      .param "x" (.tvar 1) (.done (.tvar 1) Eff.empty) := by
  simp [implDecl, method, MethSig.tel, signatureTel, Tel.bind, Tel.rawBind, typeEnvAt, Ty.rawBind, shiftTypes, Tel.norm, Ty.norm, Eff.norm, Eff.rawBind, rowFails, Ty.normTys, Eff.empty, Tel.shiftV, Ty.shiftV, Eff.shiftV, shiftVTys, ImplDecl.dictTys]
  funext a
  cases a with
  | name l ix => cases ix <;> simp [substAtoms, instAtoms]
  | rho i => simp [substAtoms, instAtoms]

def MutNoShift (P : Program) (B : Builtins) (id : ImplDecl) : Prop :=
  ∃ cd, P.classes id.cls = some cd ∧
    (∀ m, (id.methods m).isSome = (cd.methods m).isSome) ∧
    (∀ s, (id.supers s).isSome = decide (s ∈ cd.supers)) ∧
    Ty.HasKind P (List.replicate id.tparams.length .value) id.target cd.argumentKind ∧
    TypeAnnotations P id.tparams [] id.dictTys ∧
    (∀ m ms, cd.methods m = some ms → ∃ body, id.methods m = some body ∧
      NamesWF ms.names ms.params ∧
      let θ := typeEnvAt ms.tparams.length [id.target] []
      let t := Tel.bind θ ms.tel
      let C := ms.tparams.map TParamDecl.constraints ++ id.tparams
      let Γ := bindParams [] id.dictTys
      let t' := Tel.shiftV id.dictTys.length 0 t
      TelBodyTy P B StoreTy.empty (QTel t') C Γ [] t' body) ∧
    (∀ s ∈ cd.supers, ∃ u, id.supers s = some u ∧
      HasTypeV P B StoreTy.empty id.tparams (bindParams [] id.dictTys) []
        u (.dict s id.target))

theorem impl_typed_NoShift : MutNoShift program B implDecl := by
  refine ⟨klass, by simp [program, implDecl], ?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro m; by_cases h : m = "id" <;> simp [implDecl, klass, h]
  · intro s; by_cases h : s = "Parent" <;> simp [implDecl, klass, h]
  · rfl
  · intro a ha
    simp [ImplDecl.dictTys, implDecl] at ha
    subst a
    constructor <;> simp [Ty.WF, Ty.Sorted, Ty.Declared, implDecl]
  · intro m ms hm
    simp only [klass] at hm
    split at hm <;> simp_all only [Option.some.injEq, reduceCtorEq]
    subst ms
    refine ⟨.ret (.var 0), by simp [implDecl, *], by simp [NamesWF, method], ?_⟩
    rw [method_contract]
    exact .param (.done (.C_Return (.V_Var rfl (by intro b t e h; cases h))))
  · intro s hs
    simp only [klass, List.mem_singleton] at hs
    subst s
    refine ⟨.var 0, by simp [implDecl], .V_Var ?_ ?_⟩
    · rfl
    · intro b t e h; cases h

def MutNoValueMove (P : Program) (B : Builtins) (id : ImplDecl) : Prop :=
  ∃ cd, P.classes id.cls = some cd ∧
    (∀ m, (id.methods m).isSome = (cd.methods m).isSome) ∧
    (∀ s, (id.supers s).isSome = decide (s ∈ cd.supers)) ∧
    Ty.HasKind P (List.replicate id.tparams.length .value) id.target cd.argumentKind ∧
    TypeAnnotations P id.tparams [] id.dictTys ∧
    (∀ m ms, cd.methods m = some ms → ∃ body, id.methods m = some body ∧
      NamesWF ms.names ms.params ∧
      let θ := typeEnvAt ms.tparams.length [id.target] []
      let t := Tel.bind θ ms.tel
      let C := ms.tparams.map TParamDecl.constraints ++ id.tparams
      let Γ := bindParams [] (id.dictTys.map (Ty.shift ms.tparams.length 0))
      let t' := t
      TelBodyTy P B StoreTy.empty (QTel t') C Γ [] t' body) ∧
    (∀ s ∈ cd.supers, ∃ u, id.supers s = some u ∧
      HasTypeV P B StoreTy.empty id.tparams (bindParams [] id.dictTys) []
        u (.dict s id.target))

theorem method_contract2 :
    Tel.bind (typeEnvAt method.tparams.length [implDecl.target] []) method.tel =
      .param "x" (.tvar 1) (.done (.tvar 1) Eff.empty) := by
  simp [implDecl, method, MethSig.tel, signatureTel, Tel.bind, Tel.rawBind, typeEnvAt, Ty.rawBind, shiftTypes, Tel.norm, Ty.norm, Eff.norm, Eff.rawBind, rowFails, Ty.normTys, Eff.empty, Ty.shiftV]
  funext a
  cases a with
  | name l ix => cases ix <;> simp [substAtoms, instAtoms]
  | rho i => simp [substAtoms, instAtoms]

theorem impl_typed_NoValueMove : MutNoValueMove program B implDecl := by
  refine ⟨klass, by simp [program, implDecl], ?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro m; by_cases h : m = "id" <;> simp [implDecl, klass, h]
  · intro s; by_cases h : s = "Parent" <;> simp [implDecl, klass, h]
  · rfl
  · intro a ha
    simp [ImplDecl.dictTys, implDecl] at ha
    subst a
    constructor <;> simp [Ty.WF, Ty.Sorted, Ty.Declared, implDecl]
  · intro m ms hm
    simp only [klass] at hm
    split at hm <;> simp_all only [Option.some.injEq, reduceCtorEq]
    subst ms
    refine ⟨.ret (.var 0), by simp [implDecl, *], by simp [NamesWF, method], ?_⟩
    rw [method_contract2]
    exact .param (.done (.C_Return (.V_Var rfl (by intro b t e h; cases h))))
  · intro s hs
    simp only [klass, List.mem_singleton] at hs
    subst s
    refine ⟨.var 0, by simp [implDecl], .V_Var ?_ ?_⟩
    · rfl
    · intro b t e h; cases h

def MutSwapC (P : Program) (B : Builtins) (id : ImplDecl) : Prop :=
  ∃ cd, P.classes id.cls = some cd ∧
    (∀ m, (id.methods m).isSome = (cd.methods m).isSome) ∧
    (∀ s, (id.supers s).isSome = decide (s ∈ cd.supers)) ∧
    Ty.HasKind P (List.replicate id.tparams.length .value) id.target cd.argumentKind ∧
    TypeAnnotations P id.tparams [] id.dictTys ∧
    (∀ m ms, cd.methods m = some ms → ∃ body, id.methods m = some body ∧
      NamesWF ms.names ms.params ∧
      let θ := typeEnvAt ms.tparams.length [id.target] []
      let t := Tel.bind θ ms.tel
      let C := id.tparams ++ ms.tparams.map TParamDecl.constraints
      let Γ := bindParams [] (id.dictTys.map (Ty.shift ms.tparams.length 0))
      let t' := Tel.shiftV id.dictTys.length 0 t
      TelBodyTy P B StoreTy.empty (QTel t') C Γ [] t' body) ∧
    (∀ s ∈ cd.supers, ∃ u, id.supers s = some u ∧
      HasTypeV P B StoreTy.empty id.tparams (bindParams [] id.dictTys) []
        u (.dict s id.target))

theorem impl_typed_SwapC : MutSwapC program B implDecl := by
  refine ⟨klass, by simp [program, implDecl], ?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro m; by_cases h : m = "id" <;> simp [implDecl, klass, h]
  · intro s; by_cases h : s = "Parent" <;> simp [implDecl, klass, h]
  · rfl
  · intro a ha
    simp [ImplDecl.dictTys, implDecl] at ha
    subst a
    constructor <;> simp [Ty.WF, Ty.Sorted, Ty.Declared, implDecl]
  · intro m ms hm
    simp only [klass] at hm
    split at hm <;> simp_all only [Option.some.injEq, reduceCtorEq]
    subst ms
    refine ⟨.ret (.var 0), by simp [implDecl, *], by simp [NamesWF, method], ?_⟩
    rw [method_contract]
    exact .param (.done (.C_Return (.V_Var rfl (by intro b t e h; cases h))))
  · intro s hs
    simp only [klass, List.mem_singleton] at hs
    subst s
    refine ⟨.var 0, by simp [implDecl], .V_Var ?_ ?_⟩
    · rfl
    · intro b t e h; cases h

def MutQTrue (P : Program) (B : Builtins) (id : ImplDecl) : Prop :=
  ∃ cd, P.classes id.cls = some cd ∧
    (∀ m, (id.methods m).isSome = (cd.methods m).isSome) ∧
    (∀ s, (id.supers s).isSome = decide (s ∈ cd.supers)) ∧
    Ty.HasKind P (List.replicate id.tparams.length .value) id.target cd.argumentKind ∧
    TypeAnnotations P id.tparams [] id.dictTys ∧
    (∀ m ms, cd.methods m = some ms → ∃ body, id.methods m = some body ∧
      NamesWF ms.names ms.params ∧
      let θ := typeEnvAt ms.tparams.length [id.target] []
      let t := Tel.bind θ ms.tel
      let C := ms.tparams.map TParamDecl.constraints ++ id.tparams
      let Γ := bindParams [] (id.dictTys.map (Ty.shift ms.tparams.length 0))
      let t' := Tel.shiftV id.dictTys.length 0 t
      TelBodyTy P B StoreTy.empty (fun _ => True) C Γ [] t' body) ∧
    (∀ s ∈ cd.supers, ∃ u, id.supers s = some u ∧
      HasTypeV P B StoreTy.empty id.tparams (bindParams [] id.dictTys) []
        u (.dict s id.target))

theorem impl_typed_QTrue : MutQTrue program B implDecl := by
  refine ⟨klass, by simp [program, implDecl], ?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro m; by_cases h : m = "id" <;> simp [implDecl, klass, h]
  · intro s; by_cases h : s = "Parent" <;> simp [implDecl, klass, h]
  · rfl
  · intro a ha
    simp [ImplDecl.dictTys, implDecl] at ha
    subst a
    constructor <;> simp [Ty.WF, Ty.Sorted, Ty.Declared, implDecl]
  · intro m ms hm
    simp only [klass] at hm
    split at hm <;> simp_all only [Option.some.injEq, reduceCtorEq]
    subst ms
    refine ⟨.ret (.var 0), by simp [implDecl, *], by simp [NamesWF, method], ?_⟩
    rw [method_contract]
    exact .param (.done (.C_Return (.V_Var rfl (by intro b t e h; cases h))))
  · intro s hs
    simp only [klass, List.mem_singleton] at hs
    subst s
    refine ⟨.var 0, by simp [implDecl], .V_Var ?_ ?_⟩
    · rfl
    · intro b t e h; cases h

def MutNoDict (P : Program) (B : Builtins) (id : ImplDecl) : Prop :=
  ∃ cd, P.classes id.cls = some cd ∧
    (∀ m, (id.methods m).isSome = (cd.methods m).isSome) ∧
    (∀ s, (id.supers s).isSome = decide (s ∈ cd.supers)) ∧
    Ty.HasKind P (List.replicate id.tparams.length .value) id.target cd.argumentKind ∧
    TypeAnnotations P id.tparams [] id.dictTys ∧
    (∀ m ms, cd.methods m = some ms → ∃ body, id.methods m = some body ∧
      NamesWF ms.names ms.params ∧
      let θ := typeEnvAt ms.tparams.length [id.target] []
      let t := Tel.bind θ ms.tel
      let C := ms.tparams.map TParamDecl.constraints ++ id.tparams
      let Γ : Ctx := []
      let t' := Tel.shiftV id.dictTys.length 0 t
      TelBodyTy P B StoreTy.empty (QTel t') C Γ [] t' body) ∧
    (∀ s ∈ cd.supers, ∃ u, id.supers s = some u ∧
      HasTypeV P B StoreTy.empty id.tparams (bindParams [] id.dictTys) []
        u (.dict s id.target))

theorem impl_typed_NoDict : MutNoDict program B implDecl := by
  refine ⟨klass, by simp [program, implDecl], ?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro m; by_cases h : m = "id" <;> simp [implDecl, klass, h]
  · intro s; by_cases h : s = "Parent" <;> simp [implDecl, klass, h]
  · rfl
  · intro a ha
    simp [ImplDecl.dictTys, implDecl] at ha
    subst a
    constructor <;> simp [Ty.WF, Ty.Sorted, Ty.Declared, implDecl]
  · intro m ms hm
    simp only [klass] at hm
    split at hm <;> simp_all only [Option.some.injEq, reduceCtorEq]
    subst ms
    refine ⟨.ret (.var 0), by simp [implDecl, *], by simp [NamesWF, method], ?_⟩
    rw [method_contract]
    exact .param (.done (.C_Return (.V_Var rfl (by intro b t e h; cases h))))
  · intro s hs
    simp only [klass, List.mem_singleton] at hs
    subst s
    refine ⟨.var 0, by simp [implDecl], .V_Var ?_ ?_⟩
    · rfl
    · intro b t e h; cases h

def MutDefQ (P : Program) (B : Builtins) (d : Def) : Prop :=
  NamesWF d.names d.params ∧
  Ty.HasKind P (d.tparams.map TParamDecl.kind) (.dependentFn d.tel) .value ∧
  Ty.Annotation P (d.tparams.map TParamDecl.constraints) [] (.dependentFn d.tel) ∧
  TelBodyTy P B StoreTy.empty (fun _ => True)
    (d.tparams.map TParamDecl.constraints) [] [] d.tel d.body
theorem def_typed_q : MutDefQ program B identity := by
  have h := def_typed B
  refine ⟨h.1, h.2.1, h.2.2.1, .param (.done (.C_Escape (.V_Var rfl ?_) (annotation_unit _ _ _)))⟩
  intro b t e h; cases h
end
end Benitoite.Release.Refinement.RVWMut
