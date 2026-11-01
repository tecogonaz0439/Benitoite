import Benitoite.Release.Refinement.Embedding
import Benitoite.Release.Refinement.Admissible

/-! # 旧宣言の kind を保持する写し（設計書 01-12「旧判断の適格な入力」） -/
namespace Benitoite.Release.Refinement
noncomputable section

structure DeclarationKinds where
  classArgument : ClassName → TyKind
  functionParams : FunName → List TyKind
  methodParams : ClassName → MethName → List TyKind

def DeclarationKinds.WF (K : DeclarationKinds) (P : Benitoite.Release.Program) : Prop :=
  (∀ f d, P.defs f = some d → (K.functionParams f).length = d.tparams.length) ∧
  (∀ cl cd m ms, P.classes cl = some cd → cd.methods m = some ms →
    (K.methodParams cl m).length = ms.tparams.length)

def embedTParamsWithKinds (ps : List Benitoite.Release.TParam) (ks : List TyKind) : List TParamDecl :=
  (ps.zip ks).map fun (p, k) => ⟨p, k⟩

theorem embedTParamsWithKinds_constraints (ps : List Benitoite.Release.TParam) (ks : List TyKind)
    (h : ks.length = ps.length) :
    (embedTParamsWithKinds ps ks).map TParamDecl.constraints = ps := by
  induction ps generalizing ks with
  | nil => cases ks <;> simp_all [embedTParamsWithKinds]
  | cons p ps ih =>
    cases ks with
    | nil => simp at h
    | cons k ks => simpa only [embedTParamsWithKinds, List.zip_cons_cons, List.map_cons] using
          (congrArg (p :: ·) (ih ks (Nat.succ.inj h)))

theorem embedTParamsWithKinds_kinds (ps : List Benitoite.Release.TParam) (ks : List TyKind)
    (h : ks.length = ps.length) :
    (embedTParamsWithKinds ps ks).map TParamDecl.kind = ks := by
  induction ps generalizing ks with
  | nil => cases ks <;> simp_all [embedTParamsWithKinds]
  | cons p ps ih =>
    cases ks with
    | nil => simp at h
    | cons k ks => simpa only [embedTParamsWithKinds, List.zip_cons_cons, List.map_cons] using
          (congrArg (k :: ·) (ih ks (Nat.succ.inj h)))

def legacyTypeCtx (C : List Benitoite.Release.TParam) (κ : KindCtx) : TypeCtx :=
  embedTParamsWithKinds C κ

theorem legacyTypeCtx_constraints {C κ} (h : κ.length = C.length) :
    TypeCtx.constraints (legacyTypeCtx C κ) = C :=
  embedTParamsWithKinds_constraints C κ h

theorem legacyTypeCtx_kinds {C κ} (h : κ.length = C.length) :
    TypeCtx.kinds (legacyTypeCtx C κ) = κ :=
  embedTParamsWithKinds_kinds C κ h

theorem legacyTypeCtx_length {C κ} (h : κ.length = C.length) :
    (legacyTypeCtx C κ).length = C.length := by
  have he := congrArg List.length (legacyTypeCtx_constraints h)
  simpa only [TypeCtx.constraints, List.length_map] using he

def embedDefWithKinds (ks : List TyKind) (d : Benitoite.Release.Def) : Def :=
  { embedDef d with tparams := embedTParamsWithKinds d.tparams ks }

def embedMethSigWithKinds (ks : List TyKind) (d : Benitoite.Release.MethSig) : MethSig :=
  { embedMethSig d with tparams := embedTParamsWithKinds d.tparams ks }

def embedClassDeclWithKinds (K : DeclarationKinds) (cl : ClassName)
    (d : Benitoite.Release.ClassDecl) : ClassDecl :=
  { argumentKind := K.classArgument cl, supers := d.supers,
    methods := fun m => (d.methods m).map (embedMethSigWithKinds (K.methodParams cl m)) }

def embedProgramWithKinds (K : DeclarationKinds) (P : Benitoite.Release.Program) : Program :=
  { embedProgram P with
    defs := fun f => (P.defs f).map (embedDefWithKinds (K.functionParams f))
    classes := fun cl => (P.classes cl).map (embedClassDeclWithKinds K cl) }

@[simp] theorem embedProgramWithKinds_defs (K : DeclarationKinds) (P : Benitoite.Release.Program) (f : FunName) :
    (embedProgramWithKinds K P).defs f = (P.defs f).map (embedDefWithKinds (K.functionParams f)) := rfl
@[simp] theorem embedProgramWithKinds_classes (K : DeclarationKinds) (P : Benitoite.Release.Program) (cl : ClassName) :
    (embedProgramWithKinds K P).classes cl = (P.classes cl).map (embedClassDeclWithKinds K cl) := rfl
@[simp] theorem embedClassDeclWithKinds_methods (K : DeclarationKinds) (cl : ClassName)
    (cd : Benitoite.Release.ClassDecl) (m : MethName) :
    (embedClassDeclWithKinds K cl cd).methods m =
      (cd.methods m).map (embedMethSigWithKinds (K.methodParams cl m)) := rfl
@[simp] theorem embedProgramWithKinds_cons (K : DeclarationKinds) (P : Benitoite.Release.Program) (c : ConName) :
    (embedProgramWithKinds K P).cons c = (P.cons c).map embedConDecl := rfl
@[simp] theorem embedProgramWithKinds_ops (K : DeclarationKinds) (P : Benitoite.Release.Program) (o : OpName) :
    (embedProgramWithKinds K P).ops o = (P.ops o).map embedOpDecl := rfl
@[simp] theorem embedProgramWithKinds_impls (K : DeclarationKinds) (P : Benitoite.Release.Program) (i : ImplName) :
    (embedProgramWithKinds K P).impls i = (P.impls i).map embedImplDecl := rfl
@[simp] theorem embedProgramWithKinds_effects (K : DeclarationKinds) (P : Benitoite.Release.Program) :
    (embedProgramWithKinds K P).effects = P.effects := rfl
@[simp] theorem embedProgramWithKinds_externals (K : DeclarationKinds) (P : Benitoite.Release.Program) :
    (embedProgramWithKinds K P).externals = [] := rfl
@[simp] theorem embedProgramWithKinds_dataInfo (K : DeclarationKinds) (P : Benitoite.Release.Program) :
    (embedProgramWithKinds K P).dataInfo = (fun _ => none) := rfl
@[simp] theorem embedProgramWithKinds_varianceFor (K : DeclarationKinds) (P : Benitoite.Release.Program)
    (d : DataName) (n : Nat) :
    (embedProgramWithKinds K P).varianceFor d n = List.replicate n .invariant := rfl

end
end Benitoite.Release.Refinement
