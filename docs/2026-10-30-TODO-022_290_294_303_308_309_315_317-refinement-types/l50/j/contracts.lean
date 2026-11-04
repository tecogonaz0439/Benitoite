import Benitoite
import Lean.Elab.Command
namespace ScopeModelContracts
open Benitoite.Release.Refinement

-- 群Aで固定した三つの入口の全称の型。
example : ∀ P, ModelScopeConditions P Model.builtins := Model.scopeConditions
example : ∀ P, ScopeDeclarations.HasFile P → ModelScopeConditions P ModelTargets.builtins := ModelTargets.scopeConditions
example : ∀ P, ScopeDeclarations.HasHttp P → ModelScopeConditions P ModelHttp.builtins := ModelHttp.scopeConditions

theorem Model_sat_rename :
∀ (_P : Benitoite.Release.Refinement.Program) (C : Benitoite.Release.Refinement.TypeCtx)
  (Γ Δ : Benitoite.Release.Refinement.Ctx) (a : Benitoite.Release.Refinement.Ty) (p : Benitoite.Release.TParam)
  (ξ : Nat → Nat),
  (∀ (i j : Nat), i < j → ξ i < ξ j) →
    Benitoite.Release.Refinement.Ty.Annotation _P C Γ a →
      Benitoite.Release.Refinement.Ty.Annotation _P C Δ (Benitoite.Release.Refinement.renameTy ξ a) →
        Benitoite.Release.Refinement.Model.builtins.sat C.constraints a p →
          Benitoite.Release.Refinement.Model.builtins.sat C.constraints (Benitoite.Release.Refinement.renameTy ξ a) p := fun _P => (Model.scopeConditions _P).sat_rename

theorem Model_admits_rename :
∀ (_P : Benitoite.Release.Refinement.Program) (b : Benitoite.Release.PrimName)
  (sg : Benitoite.Release.Refinement.PrimSig) (C : Benitoite.Release.Refinement.TypeCtx)
  (Γ Δ : Benitoite.Release.Refinement.Ctx) (ts : List Benitoite.Release.Refinement.Ty) (ξ : Nat → Nat),
  Benitoite.Release.Refinement.Model.builtins.sig b = some sg →
    (∀ (i j : Nat), i < j → ξ i < ξ j) →
      Benitoite.Release.Refinement.TypeAnnotations _P C Γ ts →
        Benitoite.Release.Refinement.TypeAnnotations _P C Δ (List.map (Benitoite.Release.Refinement.renameTy ξ) ts) →
          sg.admits C.constraints ts → sg.admits C.constraints (List.map (Benitoite.Release.Refinement.renameTy ξ) ts) := fun _P => (Model.scopeConditions _P).admits_rename

theorem Model_sat_values :
∀ (_P : Benitoite.Release.Refinement.Program) (Ψ : Benitoite.Release.Refinement.StoreTy)
  (Q : Benitoite.Release.NoFailCtx) (C : Benitoite.Release.Refinement.TypeCtx) (Γ Δ : Benitoite.Release.Refinement.Ctx)
  (Ξ : List Benitoite.Release.Refinement.Pred) (ν : Nat → Benitoite.Release.Refinement.Val)
  (a : Benitoite.Release.Refinement.Ty) (p : Benitoite.Release.TParam),
  Benitoite.Release.Refinement.TypedValueImages _P Benitoite.Release.Refinement.Model.builtins Ψ Q C Γ Δ Ξ ν →
    Benitoite.Release.Refinement.Ty.Annotation _P C Γ a →
      Benitoite.Release.Refinement.Model.builtins.sat C.constraints a p →
        Benitoite.Release.Refinement.Model.builtins.sat C.constraints (Benitoite.Release.Refinement.substTyValues ν a) p := fun _P => (Model.scopeConditions _P).sat_values

theorem Model_admits_values :
∀ (_P : Benitoite.Release.Refinement.Program) (b : Benitoite.Release.PrimName)
  (sg : Benitoite.Release.Refinement.PrimSig) (Ψ : Benitoite.Release.Refinement.StoreTy)
  (Q : Benitoite.Release.NoFailCtx) (C : Benitoite.Release.Refinement.TypeCtx) (Γ Δ : Benitoite.Release.Refinement.Ctx)
  (Ξ : List Benitoite.Release.Refinement.Pred) (ν : Nat → Benitoite.Release.Refinement.Val)
  (ts : List Benitoite.Release.Refinement.Ty),
  Benitoite.Release.Refinement.Model.builtins.sig b = some sg →
    Benitoite.Release.Refinement.TypedValueImages _P Benitoite.Release.Refinement.Model.builtins Ψ Q C Γ Δ Ξ ν →
      Benitoite.Release.Refinement.TypeAnnotations _P C Γ ts →
        sg.admits C.constraints ts →
          sg.admits C.constraints (List.map (Benitoite.Release.Refinement.substTyValues ν) ts) := fun _P => (Model.scopeConditions _P).admits_values

theorem Model_sat_renameTypes :
∀ (_P : Benitoite.Release.Refinement.Program) (C C' : Benitoite.Release.Refinement.TypeCtx)
  (Γ Δ : Benitoite.Release.Refinement.Ctx) (a : Benitoite.Release.Refinement.Ty) (p : Benitoite.Release.TParam)
  (ρ : Nat → Nat),
  Benitoite.Release.Refinement.TypeParamRenaming C C' ρ →
    Benitoite.Release.Refinement.Ty.Annotation _P C Γ a →
      Benitoite.Release.Refinement.Ty.Annotation _P C' Δ (a.renameTypes ρ) →
        Benitoite.Release.Refinement.Model.builtins.sat C.constraints a p →
          Benitoite.Release.Refinement.Model.builtins.sat C'.constraints (a.renameTypes ρ) p := fun _P => (Model.scopeConditions _P).sat_renameTypes

theorem Model_admits_renameTypes :
∀ (_P : Benitoite.Release.Refinement.Program) (b : Benitoite.Release.PrimName)
  (sg : Benitoite.Release.Refinement.PrimSig) (C C' : Benitoite.Release.Refinement.TypeCtx)
  (Γ Δ : Benitoite.Release.Refinement.Ctx) (ts : List Benitoite.Release.Refinement.Ty) (ρ : Nat → Nat),
  Benitoite.Release.Refinement.Model.builtins.sig b = some sg →
    Benitoite.Release.Refinement.TypeParamRenaming C C' ρ →
      Benitoite.Release.Refinement.TypeAnnotations _P C Γ ts →
        Benitoite.Release.Refinement.TypeAnnotations _P C' Δ (List.map (fun a => a.renameTypes ρ) ts) →
          sg.admits C.constraints ts → sg.admits C'.constraints (List.map (fun a => a.renameTypes ρ) ts) := fun _P => (Model.scopeConditions _P).admits_renameTypes

theorem Model_sat_subst :
∀ (_P : Benitoite.Release.Refinement.Program) (C0 C1 : Benitoite.Release.Refinement.TypeCtx)
  (a : Benitoite.Release.Refinement.Ty) (p : Benitoite.Release.TParam) (ts : List Benitoite.Release.Refinement.Ty)
  (es : List Benitoite.Release.Refinement.Eff),
  Benitoite.Release.Refinement.Model.builtins.sat (C1 ++ C0).constraints a p →
    (∀ (t : Benitoite.Release.Refinement.Ty), t ∈ ts → Benitoite.Release.Refinement.Ty.WF 0 0 0 t) →
      Benitoite.Release.Refinement.SatAll Benitoite.Release.Refinement.Model.builtins C1 ts C0.constraints →
        ts.length = List.length C0 →
          Benitoite.Release.Refinement.Model.builtins.sat C1.constraints
            (Benitoite.Release.Refinement.Ty.substAt (List.length C1) ts es a) p := fun _P => (Model.scopeConditions _P).sat_subst

theorem Model_admits_subst :
∀ (_P : Benitoite.Release.Refinement.Program) (b : Benitoite.Release.PrimName)
  (sg : Benitoite.Release.Refinement.PrimSig) (C0 C1 : Benitoite.Release.Refinement.TypeCtx)
  (ts ts' : List Benitoite.Release.Refinement.Ty) (es' : List Benitoite.Release.Refinement.Eff),
  Benitoite.Release.Refinement.Model.builtins.sig b = some sg →
    sg.admits (C1 ++ C0).constraints ts →
      (∀ (t : Benitoite.Release.Refinement.Ty), t ∈ ts' → Benitoite.Release.Refinement.Ty.WF 0 0 0 t) →
        Benitoite.Release.Refinement.SatAll Benitoite.Release.Refinement.Model.builtins C1 ts' C0.constraints →
          ts'.length = List.length C0 →
            sg.admits C1.constraints (List.map (Benitoite.Release.Refinement.Ty.substAt (List.length C1) ts' es') ts) := fun _P => (Model.scopeConditions _P).admits_subst

theorem Model_delta_typed :
∀ (_P : Benitoite.Release.Refinement.Program) (Ψ : Benitoite.Release.Refinement.StoreTy) (b : Benitoite.Release.PrimName)
  (sg : Benitoite.Release.Refinement.PrimSig) (ts : List Benitoite.Release.Refinement.Ty)
  (es : List Benitoite.Release.Refinement.Eff) (rs : List Benitoite.Release.Refinement.RangeExpr)
  (ws : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
  (e : Benitoite.Release.Refinement.Eff),
  Benitoite.Release.Refinement.Model.builtins.sig b = some sg →
    sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
      Benitoite.Release.Refinement.BuiltinArgs _P Benitoite.Release.Refinement.Model.builtins Ψ b sg ts es rs ws a e →
        ∃ out,
          Benitoite.Release.Refinement.Model.builtins.delta b ts es rs ws = some out ∧
            (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
              Benitoite.Release.Refinement.Outcome.Typed _P Benitoite.Release.Refinement.Model.builtins Ψ out a ∧
                Benitoite.Release.Refinement.AdequateResult ws out := fun _P => (Model.scopeConditions _P).delta_typed

theorem Model_io_typed :
∀ (_P : Benitoite.Release.Refinement.Program) (Ψ : Benitoite.Release.Refinement.StoreTy) (b : Benitoite.Release.PrimName)
  (sg : Benitoite.Release.Refinement.PrimSig) (ts : List Benitoite.Release.Refinement.Ty)
  (es : List Benitoite.Release.Refinement.Eff) (rs : List Benitoite.Release.Refinement.RangeExpr)
  (ws : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
  (e : Benitoite.Release.Refinement.Eff) (out : Benitoite.Release.Refinement.Outcome)
  (obs : List Benitoite.Scope.Domain.Target),
  Benitoite.Release.Refinement.Model.builtins.sig b = some sg →
    sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
      Benitoite.Release.Refinement.BuiltinArgs _P Benitoite.Release.Refinement.Model.builtins Ψ b sg ts es rs ws a e →
        Benitoite.Release.Refinement.Model.builtins.ioResponse b ts es ws out obs →
          Benitoite.Release.Refinement.Outcome.Typed _P Benitoite.Release.Refinement.Model.builtins Ψ out a ∧
            Benitoite.Release.Refinement.AdequateResult ws out := fun _P => (Model.scopeConditions _P).io_typed

theorem Model_io_kind :
∀ (_P : Benitoite.Release.Refinement.Program) (Ψ : Benitoite.Release.Refinement.StoreTy) (b : Benitoite.Release.PrimName)
  (sg : Benitoite.Release.Refinement.PrimSig) (ts : List Benitoite.Release.Refinement.Ty)
  (es : List Benitoite.Release.Refinement.Eff) (rs : List Benitoite.Release.Refinement.RangeExpr)
  (ws : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
  (e : Benitoite.Release.Refinement.Eff) (out : Benitoite.Release.Refinement.Outcome)
  (obs : List Benitoite.Scope.Domain.Target),
  Benitoite.Release.Refinement.Model.builtins.sig b = some sg →
    Benitoite.Release.Refinement.BuiltinArgs _P Benitoite.Release.Refinement.Model.builtins Ψ b sg ts es rs ws a e →
      Benitoite.Release.Refinement.Model.builtins.ioResponse b ts es ws out obs →
        (sg.kind = Benitoite.Release.Refinement.PrimKind.io ∧
            ∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∨
          sg.kind = Benitoite.Release.Refinement.PrimKind.exit ∧
            ∀ (v : Benitoite.Release.Refinement.Val), out ≠ Benitoite.Release.Refinement.Outcome.val v := fun _P => (Model.scopeConditions _P).io_kind

theorem Model_io_exists :
∀ (_P : Benitoite.Release.Refinement.Program) (Ψ : Benitoite.Release.Refinement.StoreTy) (b : Benitoite.Release.PrimName)
  (sg : Benitoite.Release.Refinement.PrimSig) (ts : List Benitoite.Release.Refinement.Ty)
  (es : List Benitoite.Release.Refinement.Eff) (rs : List Benitoite.Release.Refinement.RangeExpr)
  (ws : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
  (e : Benitoite.Release.Refinement.Eff),
  Benitoite.Release.Refinement.Model.builtins.sig b = some sg →
    sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
      Benitoite.Release.Refinement.BuiltinArgs _P Benitoite.Release.Refinement.Model.builtins Ψ b sg ts es rs ws a e →
        ∃ out obs, Benitoite.Release.Refinement.Model.builtins.ioResponse b ts es ws out obs := fun _P => (Model.scopeConditions _P).io_exists

theorem Model_sig_scoped :
∀ (_P : Benitoite.Release.Refinement.Program) (b : Benitoite.Release.PrimName)
  (s : Benitoite.Release.Refinement.PrimSig),
  Benitoite.Release.Refinement.Model.builtins.sig b = some s → Benitoite.Release.Refinement.PrimSig.Scoped _P s := fun _P => (Model.scopeConditions _P).sig_scoped

theorem Model_sat_unconstrained :
∀ (_P : Benitoite.Release.Refinement.Program) (t : Benitoite.Release.Refinement.Ty),
  Benitoite.Release.Refinement.Ty.WF 0 0 0 t → Benitoite.Release.Refinement.Model.builtins.sat [] t.norm { } := fun _P => (Model.scopeConditions _P).sat_unconstrained

theorem Model_admits_sat :
∀ (_P : Benitoite.Release.Refinement.Program) (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig)
  (C : Benitoite.Release.Refinement.TypeCtx) (ts : List Benitoite.Release.Refinement.Ty),
  Benitoite.Release.Refinement.Model.builtins.sig b = some s →
    s.admits C.constraints (Benitoite.Release.Refinement.Ty.normTys ts) →
      Benitoite.Release.Refinement.SatAll Benitoite.Release.Refinement.Model.builtins C ts
        (List.map Benitoite.Release.Refinement.TParamDecl.constraints s.tparams) := fun _P => (Model.scopeConditions _P).admits_sat

theorem Model_pathBases_shape :
∀ (_P : Benitoite.Release.Refinement.Program) (b : Benitoite.Release.PrimName)
  (s : Benitoite.Release.Refinement.PrimSig),
  Benitoite.Release.Refinement.Model.builtins.sig b = some s →
    s.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
      s.PathBasesShape Benitoite.Release.Refinement.Model.builtins b := fun _P => (Model.scopeConditions _P).pathBases_shape

theorem Model_io_op :
∀ (_P : Benitoite.Release.Refinement.Program) (b : Benitoite.Release.PrimName)
  (s : Benitoite.Release.Refinement.PrimSig),
  Benitoite.Release.Refinement.Model.builtins.sig b = some s →
    s.kind = Benitoite.Release.Refinement.PrimKind.io ∨ s.kind = Benitoite.Release.Refinement.PrimKind.exit →
      Benitoite.Release.Refinement.Model.builtins.ShapeOk b s := fun _P => (Model.scopeConditions _P).io_op

theorem Model_opEff_io :
∀ (_P : Benitoite.Release.Refinement.Program) (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig)
  (l : Benitoite.Release.EffName),
  Benitoite.Release.Refinement.Model.builtins.sig b = some s →
    s.opEff = some l →
      s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
        s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨ s.kind = Benitoite.Release.Refinement.PrimKind.pathBases := fun _P => (Model.scopeConditions _P).opEff_io

theorem Model_effect_ops :
∀ (_P : Benitoite.Release.Refinement.Program) (l : Benitoite.Release.EffName) (bs : List Benitoite.Release.PrimName)
  (b : Benitoite.Release.PrimName),
  Benitoite.Release.Refinement.Model.builtins.effects l = some bs →
    b ∈ bs →
      ∃ s,
        Benitoite.Release.Refinement.Model.builtins.sig b = some s ∧
          (s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
              s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
                s.kind = Benitoite.Release.Refinement.PrimKind.pathBases) ∧
            s.opEff = some l := fun _P => (Model.scopeConditions _P).effect_ops

theorem Model_state_effect :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.Model.builtins.effects Benitoite.Release.stateEff = some [] := fun _P => (Model.scopeConditions _P).state_effect

theorem Model_ref_get :
∀ (_P : Benitoite.Release.Refinement.Program),
  ∃ s,
    Benitoite.Release.Refinement.Model.builtins.sig Benitoite.Release.Refinement.Model.builtins.refGet = some s ∧
      s.kind = Benitoite.Release.Refinement.PrimKind.refGet := fun _P => (Model.scopeConditions _P).ref_get

theorem Model_ref_set :
∀ (_P : Benitoite.Release.Refinement.Program),
  ∃ s,
    Benitoite.Release.Refinement.Model.builtins.sig Benitoite.Release.Refinement.Model.builtins.refSet = some s ∧
      s.kind = Benitoite.Release.Refinement.PrimKind.refSet := fun _P => (Model.scopeConditions _P).ref_set

theorem Model_store_shape :
∀ (_P : Benitoite.Release.Refinement.Program) (b : Benitoite.Release.PrimName)
  (s : Benitoite.Release.Refinement.PrimSig),
  Benitoite.Release.Refinement.Model.builtins.sig b = some s →
    s.kind ≠ Benitoite.Release.Refinement.PrimKind.pathBases → s.StoreShape := fun _P => (Model.scopeConditions _P).store_shape

theorem Model_store_admits :
∀ (_P : Benitoite.Release.Refinement.Program) (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig)
  (C : List Benitoite.Release.TParam) (ts : List Benitoite.Release.Refinement.Ty),
  Benitoite.Release.Refinement.Model.builtins.sig b = some s →
    s.kind ≠ Benitoite.Release.Refinement.PrimKind.pure →
      s.kind ≠ Benitoite.Release.Refinement.PrimKind.io →
        s.kind ≠ Benitoite.Release.Refinement.PrimKind.exit →
          s.kind ≠ Benitoite.Release.Refinement.PrimKind.pathBases → ts.length = s.tparams.length → s.admits C ts := fun _P => (Model.scopeConditions _P).store_admits

theorem Model_io_target :
∀ (_P : Benitoite.Release.Refinement.Program) (Ψ : Benitoite.Release.Refinement.StoreTy) (b : Benitoite.Release.PrimName)
  (sg : Benitoite.Release.Refinement.PrimSig) (ts : List Benitoite.Release.Refinement.Ty)
  (es : List Benitoite.Release.Refinement.Eff) (rs : List Benitoite.Release.Refinement.RangeExpr)
  (ws : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
  (e : Benitoite.Release.Refinement.Eff) (out : Benitoite.Release.Refinement.Outcome)
  (obs : List Benitoite.Scope.Domain.Target),
  Benitoite.Release.Refinement.Model.builtins.sig b = some sg →
    sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
      Benitoite.Release.Refinement.BuiltinArgs _P Benitoite.Release.Refinement.Model.builtins Ψ b sg ts es rs ws a e →
        Benitoite.Release.Refinement.Model.builtins.ioResponse b ts es ws out obs →
          Benitoite.Scope.Signature.ShapeTargets Benitoite.Release.Refinement.Val.target? (sg.shapeAt ws) ws obs := fun _P => (Model.scopeConditions _P).io_target

theorem ModelTargets_sat_rename :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile _P →
    ∀ (C : Benitoite.Release.Refinement.TypeCtx) (Γ Δ : Benitoite.Release.Refinement.Ctx)
      (a : Benitoite.Release.Refinement.Ty) (p : Benitoite.Release.TParam) (ξ : Nat → Nat),
      (∀ (i j : Nat), i < j → ξ i < ξ j) →
        Benitoite.Release.Refinement.Ty.Annotation _P C Γ a →
          Benitoite.Release.Refinement.Ty.Annotation _P C Δ (Benitoite.Release.Refinement.renameTy ξ a) →
            Benitoite.Release.Refinement.ModelTargets.builtins.sat C.constraints a p →
              Benitoite.Release.Refinement.ModelTargets.builtins.sat C.constraints
                (Benitoite.Release.Refinement.renameTy ξ a) p := fun _P hp => (ModelTargets.scopeConditions _P hp).sat_rename

theorem ModelTargets_admits_rename :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile _P →
    ∀ (b : Benitoite.Release.PrimName) (sg : Benitoite.Release.Refinement.PrimSig)
      (C : Benitoite.Release.Refinement.TypeCtx) (Γ Δ : Benitoite.Release.Refinement.Ctx)
      (ts : List Benitoite.Release.Refinement.Ty) (ξ : Nat → Nat),
      Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some sg →
        (∀ (i j : Nat), i < j → ξ i < ξ j) →
          Benitoite.Release.Refinement.TypeAnnotations _P C Γ ts →
            Benitoite.Release.Refinement.TypeAnnotations _P C Δ (List.map (Benitoite.Release.Refinement.renameTy ξ) ts) →
              sg.admits C.constraints ts →
                sg.admits C.constraints (List.map (Benitoite.Release.Refinement.renameTy ξ) ts) := fun _P hp => (ModelTargets.scopeConditions _P hp).admits_rename

theorem ModelTargets_sat_values :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile _P →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (Q : Benitoite.Release.NoFailCtx)
      (C : Benitoite.Release.Refinement.TypeCtx) (Γ Δ : Benitoite.Release.Refinement.Ctx)
      (Ξ : List Benitoite.Release.Refinement.Pred) (ν : Nat → Benitoite.Release.Refinement.Val)
      (a : Benitoite.Release.Refinement.Ty) (p : Benitoite.Release.TParam),
      Benitoite.Release.Refinement.TypedValueImages _P Benitoite.Release.Refinement.ModelTargets.builtins Ψ Q C Γ Δ Ξ ν →
        Benitoite.Release.Refinement.Ty.Annotation _P C Γ a →
          Benitoite.Release.Refinement.ModelTargets.builtins.sat C.constraints a p →
            Benitoite.Release.Refinement.ModelTargets.builtins.sat C.constraints
              (Benitoite.Release.Refinement.substTyValues ν a) p := fun _P hp => (ModelTargets.scopeConditions _P hp).sat_values

theorem ModelTargets_admits_values :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile _P →
    ∀ (b : Benitoite.Release.PrimName) (sg : Benitoite.Release.Refinement.PrimSig)
      (Ψ : Benitoite.Release.Refinement.StoreTy) (Q : Benitoite.Release.NoFailCtx)
      (C : Benitoite.Release.Refinement.TypeCtx) (Γ Δ : Benitoite.Release.Refinement.Ctx)
      (Ξ : List Benitoite.Release.Refinement.Pred) (ν : Nat → Benitoite.Release.Refinement.Val)
      (ts : List Benitoite.Release.Refinement.Ty),
      Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some sg →
        Benitoite.Release.Refinement.TypedValueImages _P Benitoite.Release.Refinement.ModelTargets.builtins Ψ Q C Γ Δ Ξ
            ν →
          Benitoite.Release.Refinement.TypeAnnotations _P C Γ ts →
            sg.admits C.constraints ts →
              sg.admits C.constraints (List.map (Benitoite.Release.Refinement.substTyValues ν) ts) := fun _P hp => (ModelTargets.scopeConditions _P hp).admits_values

theorem ModelTargets_sat_renameTypes :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile _P →
    ∀ (C C' : Benitoite.Release.Refinement.TypeCtx) (Γ Δ : Benitoite.Release.Refinement.Ctx)
      (a : Benitoite.Release.Refinement.Ty) (p : Benitoite.Release.TParam) (ρ : Nat → Nat),
      Benitoite.Release.Refinement.TypeParamRenaming C C' ρ →
        Benitoite.Release.Refinement.Ty.Annotation _P C Γ a →
          Benitoite.Release.Refinement.Ty.Annotation _P C' Δ (a.renameTypes ρ) →
            Benitoite.Release.Refinement.ModelTargets.builtins.sat C.constraints a p →
              Benitoite.Release.Refinement.ModelTargets.builtins.sat C'.constraints (a.renameTypes ρ) p := fun _P hp => (ModelTargets.scopeConditions _P hp).sat_renameTypes

theorem ModelTargets_admits_renameTypes :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile _P →
    ∀ (b : Benitoite.Release.PrimName) (sg : Benitoite.Release.Refinement.PrimSig)
      (C C' : Benitoite.Release.Refinement.TypeCtx) (Γ Δ : Benitoite.Release.Refinement.Ctx)
      (ts : List Benitoite.Release.Refinement.Ty) (ρ : Nat → Nat),
      Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some sg →
        Benitoite.Release.Refinement.TypeParamRenaming C C' ρ →
          Benitoite.Release.Refinement.TypeAnnotations _P C Γ ts →
            Benitoite.Release.Refinement.TypeAnnotations _P C' Δ (List.map (fun a => a.renameTypes ρ) ts) →
              sg.admits C.constraints ts → sg.admits C'.constraints (List.map (fun a => a.renameTypes ρ) ts) := fun _P hp => (ModelTargets.scopeConditions _P hp).admits_renameTypes

theorem ModelTargets_sat_subst :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile _P →
    ∀ (C0 C1 : Benitoite.Release.Refinement.TypeCtx) (a : Benitoite.Release.Refinement.Ty)
      (p : Benitoite.Release.TParam) (ts : List Benitoite.Release.Refinement.Ty)
      (es : List Benitoite.Release.Refinement.Eff),
      Benitoite.Release.Refinement.ModelTargets.builtins.sat (C1 ++ C0).constraints a p →
        (∀ (t : Benitoite.Release.Refinement.Ty), t ∈ ts → Benitoite.Release.Refinement.Ty.WF 0 0 0 t) →
          Benitoite.Release.Refinement.SatAll Benitoite.Release.Refinement.ModelTargets.builtins C1 ts C0.constraints →
            ts.length = List.length C0 →
              Benitoite.Release.Refinement.ModelTargets.builtins.sat C1.constraints
                (Benitoite.Release.Refinement.Ty.substAt (List.length C1) ts es a) p := fun _P hp => (ModelTargets.scopeConditions _P hp).sat_subst

theorem ModelTargets_admits_subst :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile _P →
    ∀ (b : Benitoite.Release.PrimName) (sg : Benitoite.Release.Refinement.PrimSig)
      (C0 C1 : Benitoite.Release.Refinement.TypeCtx) (ts ts' : List Benitoite.Release.Refinement.Ty)
      (es' : List Benitoite.Release.Refinement.Eff),
      Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some sg →
        sg.admits (C1 ++ C0).constraints ts →
          (∀ (t : Benitoite.Release.Refinement.Ty), t ∈ ts' → Benitoite.Release.Refinement.Ty.WF 0 0 0 t) →
            Benitoite.Release.Refinement.SatAll Benitoite.Release.Refinement.ModelTargets.builtins C1 ts'
                C0.constraints →
              ts'.length = List.length C0 →
                sg.admits C1.constraints
                  (List.map (Benitoite.Release.Refinement.Ty.substAt (List.length C1) ts' es') ts) := fun _P hp => (ModelTargets.scopeConditions _P hp).admits_subst

theorem ModelTargets_delta_typed :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile _P →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (b : Benitoite.Release.PrimName)
      (sg : Benitoite.Release.Refinement.PrimSig) (ts : List Benitoite.Release.Refinement.Ty)
      (es : List Benitoite.Release.Refinement.Eff) (rs : List Benitoite.Release.Refinement.RangeExpr)
      (ws : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff),
      Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some sg →
        sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
          Benitoite.Release.Refinement.BuiltinArgs _P Benitoite.Release.Refinement.ModelTargets.builtins Ψ b sg ts es rs
              ws a e →
            ∃ out,
              Benitoite.Release.Refinement.ModelTargets.builtins.delta b ts es rs ws = some out ∧
                (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                  Benitoite.Release.Refinement.Outcome.Typed _P Benitoite.Release.Refinement.ModelTargets.builtins Ψ out
                      a ∧
                    Benitoite.Release.Refinement.AdequateResult ws out := fun _P hp => (ModelTargets.scopeConditions _P hp).delta_typed

theorem ModelTargets_io_typed :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile _P →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (b : Benitoite.Release.PrimName)
      (sg : Benitoite.Release.Refinement.PrimSig) (ts : List Benitoite.Release.Refinement.Ty)
      (es : List Benitoite.Release.Refinement.Eff) (rs : List Benitoite.Release.Refinement.RangeExpr)
      (ws : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff) (out : Benitoite.Release.Refinement.Outcome)
      (obs : List Benitoite.Scope.Domain.Target),
      Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some sg →
        sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
          Benitoite.Release.Refinement.BuiltinArgs _P Benitoite.Release.Refinement.ModelTargets.builtins Ψ b sg ts es rs
              ws a e →
            Benitoite.Release.Refinement.ModelTargets.builtins.ioResponse b ts es ws out obs →
              Benitoite.Release.Refinement.Outcome.Typed _P Benitoite.Release.Refinement.ModelTargets.builtins Ψ out a ∧
                Benitoite.Release.Refinement.AdequateResult ws out := fun _P hp => (ModelTargets.scopeConditions _P hp).io_typed

theorem ModelTargets_io_kind :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile _P →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (b : Benitoite.Release.PrimName)
      (sg : Benitoite.Release.Refinement.PrimSig) (ts : List Benitoite.Release.Refinement.Ty)
      (es : List Benitoite.Release.Refinement.Eff) (rs : List Benitoite.Release.Refinement.RangeExpr)
      (ws : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff) (out : Benitoite.Release.Refinement.Outcome)
      (obs : List Benitoite.Scope.Domain.Target),
      Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some sg →
        Benitoite.Release.Refinement.BuiltinArgs _P Benitoite.Release.Refinement.ModelTargets.builtins Ψ b sg ts es rs ws
            a e →
          Benitoite.Release.Refinement.ModelTargets.builtins.ioResponse b ts es ws out obs →
            (sg.kind = Benitoite.Release.Refinement.PrimKind.io ∧
                ∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∨
              sg.kind = Benitoite.Release.Refinement.PrimKind.exit ∧
                ∀ (v : Benitoite.Release.Refinement.Val), out ≠ Benitoite.Release.Refinement.Outcome.val v := fun _P hp => (ModelTargets.scopeConditions _P hp).io_kind

theorem ModelTargets_io_exists :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile _P →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (b : Benitoite.Release.PrimName)
      (sg : Benitoite.Release.Refinement.PrimSig) (ts : List Benitoite.Release.Refinement.Ty)
      (es : List Benitoite.Release.Refinement.Eff) (rs : List Benitoite.Release.Refinement.RangeExpr)
      (ws : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff),
      Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some sg →
        sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
          Benitoite.Release.Refinement.BuiltinArgs _P Benitoite.Release.Refinement.ModelTargets.builtins Ψ b sg ts es rs
              ws a e →
            ∃ out obs, Benitoite.Release.Refinement.ModelTargets.builtins.ioResponse b ts es ws out obs := fun _P hp => (ModelTargets.scopeConditions _P hp).io_exists

theorem ModelTargets_sig_scoped :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile _P →
    ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig),
      Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some s →
        Benitoite.Release.Refinement.PrimSig.Scoped _P s := fun _P hp => (ModelTargets.scopeConditions _P hp).sig_scoped

theorem ModelTargets_sat_unconstrained :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile _P →
    ∀ (t : Benitoite.Release.Refinement.Ty),
      Benitoite.Release.Refinement.Ty.WF 0 0 0 t → Benitoite.Release.Refinement.ModelTargets.builtins.sat [] t.norm { } := fun _P hp => (ModelTargets.scopeConditions _P hp).sat_unconstrained

theorem ModelTargets_admits_sat :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile _P →
    ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig)
      (C : Benitoite.Release.Refinement.TypeCtx) (ts : List Benitoite.Release.Refinement.Ty),
      Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some s →
        s.admits C.constraints (Benitoite.Release.Refinement.Ty.normTys ts) →
          Benitoite.Release.Refinement.SatAll Benitoite.Release.Refinement.ModelTargets.builtins C ts
            (List.map Benitoite.Release.Refinement.TParamDecl.constraints s.tparams) := fun _P hp => (ModelTargets.scopeConditions _P hp).admits_sat

theorem ModelTargets_pathBases_shape :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile _P →
    ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig),
      Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some s →
        s.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
          s.PathBasesShape Benitoite.Release.Refinement.ModelTargets.builtins b := fun _P hp => (ModelTargets.scopeConditions _P hp).pathBases_shape

theorem ModelTargets_io_op :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile _P →
    ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig),
      Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some s →
        s.kind = Benitoite.Release.Refinement.PrimKind.io ∨ s.kind = Benitoite.Release.Refinement.PrimKind.exit →
          Benitoite.Release.Refinement.ModelTargets.builtins.ShapeOk b s := fun _P hp => (ModelTargets.scopeConditions _P hp).io_op

theorem ModelTargets_opEff_io :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile _P →
    ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig) (l : Benitoite.Release.EffName),
      Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some s →
        s.opEff = some l →
          s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
            s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
              s.kind = Benitoite.Release.Refinement.PrimKind.pathBases := fun _P hp => (ModelTargets.scopeConditions _P hp).opEff_io

theorem ModelTargets_effect_ops :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile _P →
    ∀ (l : Benitoite.Release.EffName) (bs : List Benitoite.Release.PrimName) (b : Benitoite.Release.PrimName),
      Benitoite.Release.Refinement.ModelTargets.builtins.effects l = some bs →
        b ∈ bs →
          ∃ s,
            Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some s ∧
              (s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
                  s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
                    s.kind = Benitoite.Release.Refinement.PrimKind.pathBases) ∧
                s.opEff = some l := fun _P hp => (ModelTargets.scopeConditions _P hp).effect_ops

theorem ModelTargets_state_effect :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile _P →
    Benitoite.Release.Refinement.ModelTargets.builtins.effects Benitoite.Release.stateEff = some [] := fun _P hp => (ModelTargets.scopeConditions _P hp).state_effect

theorem ModelTargets_ref_get :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile _P →
    ∃ s,
      Benitoite.Release.Refinement.ModelTargets.builtins.sig Benitoite.Release.Refinement.ModelTargets.builtins.refGet =
          some s ∧
        s.kind = Benitoite.Release.Refinement.PrimKind.refGet := fun _P hp => (ModelTargets.scopeConditions _P hp).ref_get

theorem ModelTargets_ref_set :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile _P →
    ∃ s,
      Benitoite.Release.Refinement.ModelTargets.builtins.sig Benitoite.Release.Refinement.ModelTargets.builtins.refSet =
          some s ∧
        s.kind = Benitoite.Release.Refinement.PrimKind.refSet := fun _P hp => (ModelTargets.scopeConditions _P hp).ref_set

theorem ModelTargets_store_shape :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile _P →
    ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig),
      Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some s →
        s.kind ≠ Benitoite.Release.Refinement.PrimKind.pathBases → s.StoreShape := fun _P hp => (ModelTargets.scopeConditions _P hp).store_shape

theorem ModelTargets_store_admits :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile _P →
    ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig) (C : List Benitoite.Release.TParam)
      (ts : List Benitoite.Release.Refinement.Ty),
      Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some s →
        s.kind ≠ Benitoite.Release.Refinement.PrimKind.pure →
          s.kind ≠ Benitoite.Release.Refinement.PrimKind.io →
            s.kind ≠ Benitoite.Release.Refinement.PrimKind.exit →
              s.kind ≠ Benitoite.Release.Refinement.PrimKind.pathBases → ts.length = s.tparams.length → s.admits C ts := fun _P hp => (ModelTargets.scopeConditions _P hp).store_admits

theorem ModelTargets_io_target :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile _P →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (b : Benitoite.Release.PrimName)
      (sg : Benitoite.Release.Refinement.PrimSig) (ts : List Benitoite.Release.Refinement.Ty)
      (es : List Benitoite.Release.Refinement.Eff) (rs : List Benitoite.Release.Refinement.RangeExpr)
      (ws : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff) (out : Benitoite.Release.Refinement.Outcome)
      (obs : List Benitoite.Scope.Domain.Target),
      Benitoite.Release.Refinement.ModelTargets.builtins.sig b = some sg →
        sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
          Benitoite.Release.Refinement.BuiltinArgs _P Benitoite.Release.Refinement.ModelTargets.builtins Ψ b sg ts es rs
              ws a e →
            Benitoite.Release.Refinement.ModelTargets.builtins.ioResponse b ts es ws out obs →
              Benitoite.Scope.Signature.ShapeTargets Benitoite.Release.Refinement.Val.target? (sg.shapeAt ws) ws obs := fun _P hp => (ModelTargets.scopeConditions _P hp).io_target

theorem ModelHttp_sat_rename :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp _P →
    ∀ (C : Benitoite.Release.Refinement.TypeCtx) (Γ Δ : Benitoite.Release.Refinement.Ctx)
      (a : Benitoite.Release.Refinement.Ty) (p : Benitoite.Release.TParam) (ξ : Nat → Nat),
      (∀ (i j : Nat), i < j → ξ i < ξ j) →
        Benitoite.Release.Refinement.Ty.Annotation _P C Γ a →
          Benitoite.Release.Refinement.Ty.Annotation _P C Δ (Benitoite.Release.Refinement.renameTy ξ a) →
            Benitoite.Release.Refinement.ModelHttp.builtins.sat C.constraints a p →
              Benitoite.Release.Refinement.ModelHttp.builtins.sat C.constraints
                (Benitoite.Release.Refinement.renameTy ξ a) p := fun _P hp => (ModelHttp.scopeConditions _P hp).sat_rename

theorem ModelHttp_admits_rename :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp _P →
    ∀ (b : Benitoite.Release.PrimName) (sg : Benitoite.Release.Refinement.PrimSig)
      (C : Benitoite.Release.Refinement.TypeCtx) (Γ Δ : Benitoite.Release.Refinement.Ctx)
      (ts : List Benitoite.Release.Refinement.Ty) (ξ : Nat → Nat),
      Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some sg →
        (∀ (i j : Nat), i < j → ξ i < ξ j) →
          Benitoite.Release.Refinement.TypeAnnotations _P C Γ ts →
            Benitoite.Release.Refinement.TypeAnnotations _P C Δ (List.map (Benitoite.Release.Refinement.renameTy ξ) ts) →
              sg.admits C.constraints ts →
                sg.admits C.constraints (List.map (Benitoite.Release.Refinement.renameTy ξ) ts) := fun _P hp => (ModelHttp.scopeConditions _P hp).admits_rename

theorem ModelHttp_sat_values :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp _P →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (Q : Benitoite.Release.NoFailCtx)
      (C : Benitoite.Release.Refinement.TypeCtx) (Γ Δ : Benitoite.Release.Refinement.Ctx)
      (Ξ : List Benitoite.Release.Refinement.Pred) (ν : Nat → Benitoite.Release.Refinement.Val)
      (a : Benitoite.Release.Refinement.Ty) (p : Benitoite.Release.TParam),
      Benitoite.Release.Refinement.TypedValueImages _P Benitoite.Release.Refinement.ModelHttp.builtins Ψ Q C Γ Δ Ξ ν →
        Benitoite.Release.Refinement.Ty.Annotation _P C Γ a →
          Benitoite.Release.Refinement.ModelHttp.builtins.sat C.constraints a p →
            Benitoite.Release.Refinement.ModelHttp.builtins.sat C.constraints
              (Benitoite.Release.Refinement.substTyValues ν a) p := fun _P hp => (ModelHttp.scopeConditions _P hp).sat_values

theorem ModelHttp_admits_values :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp _P →
    ∀ (b : Benitoite.Release.PrimName) (sg : Benitoite.Release.Refinement.PrimSig)
      (Ψ : Benitoite.Release.Refinement.StoreTy) (Q : Benitoite.Release.NoFailCtx)
      (C : Benitoite.Release.Refinement.TypeCtx) (Γ Δ : Benitoite.Release.Refinement.Ctx)
      (Ξ : List Benitoite.Release.Refinement.Pred) (ν : Nat → Benitoite.Release.Refinement.Val)
      (ts : List Benitoite.Release.Refinement.Ty),
      Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some sg →
        Benitoite.Release.Refinement.TypedValueImages _P Benitoite.Release.Refinement.ModelHttp.builtins Ψ Q C Γ Δ Ξ ν →
          Benitoite.Release.Refinement.TypeAnnotations _P C Γ ts →
            sg.admits C.constraints ts →
              sg.admits C.constraints (List.map (Benitoite.Release.Refinement.substTyValues ν) ts) := fun _P hp => (ModelHttp.scopeConditions _P hp).admits_values

theorem ModelHttp_sat_renameTypes :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp _P →
    ∀ (C C' : Benitoite.Release.Refinement.TypeCtx) (Γ Δ : Benitoite.Release.Refinement.Ctx)
      (a : Benitoite.Release.Refinement.Ty) (p : Benitoite.Release.TParam) (ρ : Nat → Nat),
      Benitoite.Release.Refinement.TypeParamRenaming C C' ρ →
        Benitoite.Release.Refinement.Ty.Annotation _P C Γ a →
          Benitoite.Release.Refinement.Ty.Annotation _P C' Δ (a.renameTypes ρ) →
            Benitoite.Release.Refinement.ModelHttp.builtins.sat C.constraints a p →
              Benitoite.Release.Refinement.ModelHttp.builtins.sat C'.constraints (a.renameTypes ρ) p := fun _P hp => (ModelHttp.scopeConditions _P hp).sat_renameTypes

theorem ModelHttp_admits_renameTypes :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp _P →
    ∀ (b : Benitoite.Release.PrimName) (sg : Benitoite.Release.Refinement.PrimSig)
      (C C' : Benitoite.Release.Refinement.TypeCtx) (Γ Δ : Benitoite.Release.Refinement.Ctx)
      (ts : List Benitoite.Release.Refinement.Ty) (ρ : Nat → Nat),
      Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some sg →
        Benitoite.Release.Refinement.TypeParamRenaming C C' ρ →
          Benitoite.Release.Refinement.TypeAnnotations _P C Γ ts →
            Benitoite.Release.Refinement.TypeAnnotations _P C' Δ (List.map (fun a => a.renameTypes ρ) ts) →
              sg.admits C.constraints ts → sg.admits C'.constraints (List.map (fun a => a.renameTypes ρ) ts) := fun _P hp => (ModelHttp.scopeConditions _P hp).admits_renameTypes

theorem ModelHttp_sat_subst :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp _P →
    ∀ (C0 C1 : Benitoite.Release.Refinement.TypeCtx) (a : Benitoite.Release.Refinement.Ty)
      (p : Benitoite.Release.TParam) (ts : List Benitoite.Release.Refinement.Ty)
      (es : List Benitoite.Release.Refinement.Eff),
      Benitoite.Release.Refinement.ModelHttp.builtins.sat (C1 ++ C0).constraints a p →
        (∀ (t : Benitoite.Release.Refinement.Ty), t ∈ ts → Benitoite.Release.Refinement.Ty.WF 0 0 0 t) →
          Benitoite.Release.Refinement.SatAll Benitoite.Release.Refinement.ModelHttp.builtins C1 ts C0.constraints →
            ts.length = List.length C0 →
              Benitoite.Release.Refinement.ModelHttp.builtins.sat C1.constraints
                (Benitoite.Release.Refinement.Ty.substAt (List.length C1) ts es a) p := fun _P hp => (ModelHttp.scopeConditions _P hp).sat_subst

theorem ModelHttp_admits_subst :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp _P →
    ∀ (b : Benitoite.Release.PrimName) (sg : Benitoite.Release.Refinement.PrimSig)
      (C0 C1 : Benitoite.Release.Refinement.TypeCtx) (ts ts' : List Benitoite.Release.Refinement.Ty)
      (es' : List Benitoite.Release.Refinement.Eff),
      Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some sg →
        sg.admits (C1 ++ C0).constraints ts →
          (∀ (t : Benitoite.Release.Refinement.Ty), t ∈ ts' → Benitoite.Release.Refinement.Ty.WF 0 0 0 t) →
            Benitoite.Release.Refinement.SatAll Benitoite.Release.Refinement.ModelHttp.builtins C1 ts' C0.constraints →
              ts'.length = List.length C0 →
                sg.admits C1.constraints
                  (List.map (Benitoite.Release.Refinement.Ty.substAt (List.length C1) ts' es') ts) := fun _P hp => (ModelHttp.scopeConditions _P hp).admits_subst

theorem ModelHttp_delta_typed :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp _P →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (b : Benitoite.Release.PrimName)
      (sg : Benitoite.Release.Refinement.PrimSig) (ts : List Benitoite.Release.Refinement.Ty)
      (es : List Benitoite.Release.Refinement.Eff) (rs : List Benitoite.Release.Refinement.RangeExpr)
      (ws : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff),
      Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some sg →
        sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
          Benitoite.Release.Refinement.BuiltinArgs _P Benitoite.Release.Refinement.ModelHttp.builtins Ψ b sg ts es rs ws
              a e →
            ∃ out,
              Benitoite.Release.Refinement.ModelHttp.builtins.delta b ts es rs ws = some out ∧
                (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                  Benitoite.Release.Refinement.Outcome.Typed _P Benitoite.Release.Refinement.ModelHttp.builtins Ψ out a ∧
                    Benitoite.Release.Refinement.AdequateResult ws out := fun _P hp => (ModelHttp.scopeConditions _P hp).delta_typed

theorem ModelHttp_io_typed :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp _P →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (b : Benitoite.Release.PrimName)
      (sg : Benitoite.Release.Refinement.PrimSig) (ts : List Benitoite.Release.Refinement.Ty)
      (es : List Benitoite.Release.Refinement.Eff) (rs : List Benitoite.Release.Refinement.RangeExpr)
      (ws : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff) (out : Benitoite.Release.Refinement.Outcome)
      (obs : List Benitoite.Scope.Domain.Target),
      Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some sg →
        sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
          Benitoite.Release.Refinement.BuiltinArgs _P Benitoite.Release.Refinement.ModelHttp.builtins Ψ b sg ts es rs ws
              a e →
            Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse b ts es ws out obs →
              Benitoite.Release.Refinement.Outcome.Typed _P Benitoite.Release.Refinement.ModelHttp.builtins Ψ out a ∧
                Benitoite.Release.Refinement.AdequateResult ws out := fun _P hp => (ModelHttp.scopeConditions _P hp).io_typed

theorem ModelHttp_io_kind :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp _P →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (b : Benitoite.Release.PrimName)
      (sg : Benitoite.Release.Refinement.PrimSig) (ts : List Benitoite.Release.Refinement.Ty)
      (es : List Benitoite.Release.Refinement.Eff) (rs : List Benitoite.Release.Refinement.RangeExpr)
      (ws : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff) (out : Benitoite.Release.Refinement.Outcome)
      (obs : List Benitoite.Scope.Domain.Target),
      Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some sg →
        Benitoite.Release.Refinement.BuiltinArgs _P Benitoite.Release.Refinement.ModelHttp.builtins Ψ b sg ts es rs ws a
            e →
          Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse b ts es ws out obs →
            (sg.kind = Benitoite.Release.Refinement.PrimKind.io ∧
                ∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∨
              sg.kind = Benitoite.Release.Refinement.PrimKind.exit ∧
                ∀ (v : Benitoite.Release.Refinement.Val), out ≠ Benitoite.Release.Refinement.Outcome.val v := fun _P hp => (ModelHttp.scopeConditions _P hp).io_kind

theorem ModelHttp_io_exists :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp _P →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (b : Benitoite.Release.PrimName)
      (sg : Benitoite.Release.Refinement.PrimSig) (ts : List Benitoite.Release.Refinement.Ty)
      (es : List Benitoite.Release.Refinement.Eff) (rs : List Benitoite.Release.Refinement.RangeExpr)
      (ws : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff),
      Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some sg →
        sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
          Benitoite.Release.Refinement.BuiltinArgs _P Benitoite.Release.Refinement.ModelHttp.builtins Ψ b sg ts es rs ws
              a e →
            ∃ out obs, Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse b ts es ws out obs := fun _P hp => (ModelHttp.scopeConditions _P hp).io_exists

theorem ModelHttp_sig_scoped :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp _P →
    ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig),
      Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some s → Benitoite.Release.Refinement.PrimSig.Scoped _P s := fun _P hp => (ModelHttp.scopeConditions _P hp).sig_scoped

theorem ModelHttp_sat_unconstrained :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp _P →
    ∀ (t : Benitoite.Release.Refinement.Ty),
      Benitoite.Release.Refinement.Ty.WF 0 0 0 t → Benitoite.Release.Refinement.ModelHttp.builtins.sat [] t.norm { } := fun _P hp => (ModelHttp.scopeConditions _P hp).sat_unconstrained

theorem ModelHttp_admits_sat :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp _P →
    ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig)
      (C : Benitoite.Release.Refinement.TypeCtx) (ts : List Benitoite.Release.Refinement.Ty),
      Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some s →
        s.admits C.constraints (Benitoite.Release.Refinement.Ty.normTys ts) →
          Benitoite.Release.Refinement.SatAll Benitoite.Release.Refinement.ModelHttp.builtins C ts
            (List.map Benitoite.Release.Refinement.TParamDecl.constraints s.tparams) := fun _P hp => (ModelHttp.scopeConditions _P hp).admits_sat

theorem ModelHttp_pathBases_shape :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp _P →
    ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig),
      Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some s →
        s.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
          s.PathBasesShape Benitoite.Release.Refinement.ModelHttp.builtins b := fun _P hp => (ModelHttp.scopeConditions _P hp).pathBases_shape

theorem ModelHttp_io_op :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp _P →
    ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig),
      Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some s →
        s.kind = Benitoite.Release.Refinement.PrimKind.io ∨ s.kind = Benitoite.Release.Refinement.PrimKind.exit →
          Benitoite.Release.Refinement.ModelHttp.builtins.ShapeOk b s := fun _P hp => (ModelHttp.scopeConditions _P hp).io_op

theorem ModelHttp_opEff_io :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp _P →
    ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig) (l : Benitoite.Release.EffName),
      Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some s →
        s.opEff = some l →
          s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
            s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
              s.kind = Benitoite.Release.Refinement.PrimKind.pathBases := fun _P hp => (ModelHttp.scopeConditions _P hp).opEff_io

theorem ModelHttp_effect_ops :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp _P →
    ∀ (l : Benitoite.Release.EffName) (bs : List Benitoite.Release.PrimName) (b : Benitoite.Release.PrimName),
      Benitoite.Release.Refinement.ModelHttp.builtins.effects l = some bs →
        b ∈ bs →
          ∃ s,
            Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some s ∧
              (s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
                  s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
                    s.kind = Benitoite.Release.Refinement.PrimKind.pathBases) ∧
                s.opEff = some l := fun _P hp => (ModelHttp.scopeConditions _P hp).effect_ops

theorem ModelHttp_state_effect :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp _P →
    Benitoite.Release.Refinement.ModelHttp.builtins.effects Benitoite.Release.stateEff = some [] := fun _P hp => (ModelHttp.scopeConditions _P hp).state_effect

theorem ModelHttp_ref_get :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp _P →
    ∃ s,
      Benitoite.Release.Refinement.ModelHttp.builtins.sig Benitoite.Release.Refinement.ModelHttp.builtins.refGet =
          some s ∧
        s.kind = Benitoite.Release.Refinement.PrimKind.refGet := fun _P hp => (ModelHttp.scopeConditions _P hp).ref_get

theorem ModelHttp_ref_set :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp _P →
    ∃ s,
      Benitoite.Release.Refinement.ModelHttp.builtins.sig Benitoite.Release.Refinement.ModelHttp.builtins.refSet =
          some s ∧
        s.kind = Benitoite.Release.Refinement.PrimKind.refSet := fun _P hp => (ModelHttp.scopeConditions _P hp).ref_set

theorem ModelHttp_store_shape :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp _P →
    ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig),
      Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some s →
        s.kind ≠ Benitoite.Release.Refinement.PrimKind.pathBases → s.StoreShape := fun _P hp => (ModelHttp.scopeConditions _P hp).store_shape

theorem ModelHttp_store_admits :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp _P →
    ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig) (C : List Benitoite.Release.TParam)
      (ts : List Benitoite.Release.Refinement.Ty),
      Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some s →
        s.kind ≠ Benitoite.Release.Refinement.PrimKind.pure →
          s.kind ≠ Benitoite.Release.Refinement.PrimKind.io →
            s.kind ≠ Benitoite.Release.Refinement.PrimKind.exit →
              s.kind ≠ Benitoite.Release.Refinement.PrimKind.pathBases → ts.length = s.tparams.length → s.admits C ts := fun _P hp => (ModelHttp.scopeConditions _P hp).store_admits

theorem ModelHttp_io_target :
∀ (_P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp _P →
    ∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (b : Benitoite.Release.PrimName)
      (sg : Benitoite.Release.Refinement.PrimSig) (ts : List Benitoite.Release.Refinement.Ty)
      (es : List Benitoite.Release.Refinement.Eff) (rs : List Benitoite.Release.Refinement.RangeExpr)
      (ws : List Benitoite.Release.Refinement.Val) (a : Benitoite.Release.Refinement.Ty)
      (e : Benitoite.Release.Refinement.Eff) (out : Benitoite.Release.Refinement.Outcome)
      (obs : List Benitoite.Scope.Domain.Target),
      Benitoite.Release.Refinement.ModelHttp.builtins.sig b = some sg →
        sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
          Benitoite.Release.Refinement.BuiltinArgs _P Benitoite.Release.Refinement.ModelHttp.builtins Ψ b sg ts es rs ws
              a e →
            Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse b ts es ws out obs →
              Benitoite.Scope.Signature.ShapeTargets Benitoite.Release.Refinement.Val.target? (sg.shapeAt ws) ws obs := fun _P hp => (ModelHttp.scopeConditions _P hp).io_target


-- 元の全入力を量化した純粋三行と全送信応答。
def Pure (P : Program) (B : Builtins) (b : Benitoite.Release.PrimName) : Prop :=
  ∀ Ψ sg ts es rs ws a e, B.sig b = some sg → sg.kind = .pure →
    BuiltinArgs P B Ψ b sg ts es rs ws a e →
    ∃ out, B.delta b ts es rs ws = some out ∧ (∀ n, out ≠ .exit n) ∧
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out

example {P} (hp : ScopeDeclarations.HasHttp P) : ∀ b, Pure P ModelHttp.builtins b := by
  intro b Ψ sg ts es rs ws a e hs hk args
  exact ModelHttp.delta_typed hp hs hk args

def Ground (P : Program) (B : Builtins) (b : Benitoite.Release.PrimName) : Prop :=
  ∀ Ψ sg ts es rs ws a e out v, B.sig b = some sg → sg.kind = .pure →
    BuiltinArgs P B Ψ b sg ts es rs ws a e → B.delta b ts es rs ws = some out →
    out = .val v → v.Ground

example {P} (hp : ScopeDeclarations.HasHttp P) : ∀ b, Ground P ModelHttp.builtins b := by
  intro b Ψ sg ts es rs ws a e out v hs hk args hd hv
  exact (ModelHttp.pure_outcome hp hs hk args hd).2.2.2 v hv

def IO (P : Program) (B : Builtins) (b : Benitoite.Release.PrimName) : Prop :=
  ∀ Ψ sg ts es rs ws a e, B.sig b = some sg → sg.kind = .io →
    BuiltinArgs P B Ψ b sg ts es rs ws a e →
    (∀ out obs, B.ioResponse b ts es ws out obs →
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ n, out ≠ .exit n) ∧
      Benitoite.Scope.Signature.ShapeTargets Val.target? (sg.shapeAt ws) ws obs) ∧
    ∃ out obs, B.ioResponse b ts es ws out obs

example {P} (hp : ScopeDeclarations.HasHttp P) : ∀ b, IO P ModelHttp.builtins b := by
  intro b Ψ sg ts es rs ws a e hs hk args
  refine ⟨?_,ModelHttp.io_exists hp.file hs (Or.inl hk) args⟩
  intro out obs hr
  obtain ⟨ht,ha⟩ := ModelHttp.io_typed hp.file hs (Or.inl hk) args hr
  exact ⟨ht,ha,(ModelHttp.io_kind hs hr).2,
    (ModelHttp.targetAgreement P).io_target Ψ b sg ts es rs ws a e out obs hs (Or.inl hk) args hr⟩


end ScopeModelContracts
