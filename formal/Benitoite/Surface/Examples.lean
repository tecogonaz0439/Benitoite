import Benitoite.Surface.Theorems
import Benitoite.Release.Model

/-! 名前付きの操作・型クラスを含む性質 1 の適用と、契約不一致の拒否
（設計書 01-12「型クラス」「ハンドラ」「確かめる性質」）。 -/
namespace Benitoite.Surface.Examples
open Benitoite.Release

private def intTy : Ty := .base .integer
private def opPrim : OpPrim := fun _ _ => none
private def builtins : Builtins := Release.Model.builtins

private def chooseSig : MethSig :=
  { tparams := [], neffs := 0, names := ["left", "right"],
    params := [.tvar 0, .tvar 0], ret := .tvar 0, eff := Eff.empty }

private def chooseClass : ClassDecl :=
  { supers := [], methods := fun m => if m = "choose" then some chooseSig else none }

private def chooseImpl : ImplDecl :=
  { tparams := [], dictParams := [], cls := "Choose", target := intTy,
    supers := fun _ => none,
    methods := fun m => if m = "choose" then some (.last (.returnE intTy (.local 1))) else none }

private def readOp : OpDecl :=
  { tparams := [], names := ["value"], params := [intTy], ret := intTy, eff := "Read" }

private def readCall : Expr :=
  .call (.opName "read" []) [some "value"] [0] (.cons (.literal (.integer 7)) .nil)

private def methodValue : Expr :=
  .methName (.impl "ChooseInt" [] []) "choose" [] [] [] ["left", "right"] [intTy, intTy]

private def mainExpr : Expr :=
  .handleE
    (.last (.call methodValue [some "right", some "left"] [1, 0]
      (.cons (.literal (.integer 2)) (.cons readCall .nil))))
    (.cons (.user "read") 1 0 (.last (.resume 0 (.local 1))) .nil)

private def mainDef : Def :=
  { tparams := [], neffs := 0, names := [], params := [], ret := .base .unit, eff := Eff.empty,
    body := .lastDiscard mainExpr }

private def program : Program :=
  { defs := fun f => if f = "main" then some mainDef else none,
    cons := fun _ => none,
    ops := fun o => if o = "read" then some readOp else none,
    effects := fun l => if l = "Read" then some ["read"] else none,
    classes := fun c => if c = "Choose" then some chooseClass else none,
    impls := fun i => if i = "ChooseInt" then some chooseImpl else none }

private theorem chooseSig_scoped : chooseSig.Scoped := by
  exact ⟨by simp [chooseSig, NamesWF], by simp [chooseSig, Ty.VarsInList, Ty.VarsIn],
    by simp [chooseSig, Ty.VarsIn], by simp [chooseSig, Eff.RhosIn, Eff.empty]⟩

private theorem mainExpr_typed (Γ : List (Option Ty)) (R : Option Ty) (pos : Position) :
    HasType program.declarations builtins opPrim [] Γ R pos mainExpr intTy Eff.empty := by
  have hd : DictEv.HasType program.declarations builtins [] Γ
      (.impl "ChooseInt" [] []) (.dict "Choose" intTy) := by
    have h := DictEv.HasType.impl (D := program.declarations) (B := builtins) (C := []) (Γ := Γ)
      (i := "ChooseInt") (id := chooseImpl.toImplSig) (ts := []) (ds := []) rfl
      ⟨rfl, by intro i t tp hi _; cases hi⟩ .nil
    simpa [chooseImpl, Ty.subst, Ty.substAt, intTy] using h
  have hm : HasType program.declarations builtins opPrim [] Γ R .other
      methodValue (.fn ["left", "right"] [intTy, intTy] intTy Eff.empty) Eff.empty := by
    have h := HasType.E_MethName (opPrim := opPrim) (R := R) (p := Position.other)
      (m := "choose") (cd := chooseClass) (ms := chooseSig) (ss := []) (es := []) (us := [])
      (names := ["left", "right"]) (ps := [intTy, intTy]) hd rfl rfl
      (by simp [chooseSig, NamesWF]) rfl ⟨rfl, by intro i t tp hi _; cases hi⟩ rfl .nil
      (by simp [chooseSig, Ty.subst, Ty.substAt, Ty.shift_zero])
      (by intro a ha cl t; simp at ha; subst a; intro h; cases h)
    simpa [methodValue, chooseSig, Ty.subst, Ty.substAt, Ty.shift_zero, intTy, Eff.substRho_empty] using h
  have hr : HasType program.declarations builtins opPrim [] Γ R .other
      readCall intTy (Eff.single "Read") := by
    have hop := HasType.E_Op (D := program.declarations) (B := builtins) (opPrim := opPrim)
      (C := []) (Γ := Γ) (R := R) (p := Position.other) (o := "read") (od := readOp) (ts := [])
      rfl (by simp [readOp, NamesWF]) ⟨rfl, by intro i t tp hi _; cases hi⟩
    have he : Eff.substRho [] (Eff.single "Read") = Eff.single "Read" := by
      funext a; cases a <;> simp [Eff.substRho, Eff.single]
    have hf : HasType program.declarations builtins opPrim [] Γ R .other
        (.opName "read" []) (.fn ["value"] [intTy] intTy (Eff.single "Read")) Eff.empty := by
      simpa [fnTy_eq, readOp, intTy, Ty.subst, Ty.substAt, he] using hop
    have hp : CallOk ["value"] [intTy] false [some "value"] [0] := by
      exact ⟨by simp [NamesWF], rfl, List.Perm.refl _, Or.inr (Or.inr ⟨rfl, by intro label h; simp at h; subst label; rfl⟩)⟩
    simpa [readCall, union_empty_left] using
      HasType.E_Call (p := Position.other) hf hp (HasTypes.cons (.E_Literal (l := .integer 7)) .nil)
  have hp : CallOk ["left", "right"] [intTy, intTy] false [some "right", some "left"] [1, 0] := by
    refine ⟨by simp [NamesWF], rfl, List.Perm.swap _ _ [], Or.inr (Or.inr ⟨rfl, ?_⟩)⟩
    intro label h; simp at h; rcases h with rfl | rfl <;> rfl
  have hb := HasType.E_Call (p := Position.other) hm hp
    (HasTypes.cons (.E_Literal (l := .integer 2)) (HasTypes.cons hr .nil))
  apply HasType.E_Handle (HasBlock.B_Last (by simpa [union_empty_left, union_empty_right] using hb))
  · intro a ha
    have he : a = .name "Read" := by simpa [Eff.single] using ha
    subst a
    rfl
  · apply HasClauses.cons
      (sg := { tparams := [], names := ["value"], params := [intTy], ret := intTy, eff := "Read" })
      rfl (by simp [NamesWF]) rfl rfl
    · exact .B_Last (.E_Resume rfl (.E_Local rfl (by intro b t ε h; cases h)))
    · exact .nil

private theorem program_wellFormed : program.WellFormed := by
  refine ⟨(fun _ _ h => by cases h), ?_, (fun _ _ h => by cases h), ?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro f d h
    simp only [program] at h
    split at h
    · cases h
      simp [Def.Scoped, mainDef, FunDecl.coreNames, internalNames, FunDecl.dictTys, NamesWF,
        Expr.Scoped, Block.Scoped, mainExpr, methodValue, readCall,
        DictEv.Scoped, DictEv.ScopedList, Exprs.Scoped, Clauses.Scoped,
        intTy, Ty.VarsInList, Ty.VarsIn, Eff.RhosIn, Eff.empty, Eff.RhosInList]
    · cases h
  · intro o od h
    simp only [program] at h
    split at h
    · cases h
      simp [OpDecl.Scoped, readOp, NamesWF, intTy, Ty.VarsInList, Ty.VarsIn]
    · cases h
  · intro l os o h ho
    simp only [program] at h
    split at h
    · cases h
      simp only [List.mem_singleton] at ho
      subst o
      exact ⟨readOp, rfl, by simpa [readOp] using (by assumption : l = "Read").symm⟩
    · cases h
  · intro o od h
    simp only [program] at h
    split at h
    · cases h; exact ⟨["read"], rfl, by simp [*]⟩
    · cases h
  · intro c cd h m ms hm
    simp only [program] at h
    split at h
    · cases h
      simp only [chooseClass] at hm
      split at hm
      · cases hm; exact chooseSig_scoped
      · cases hm
    · cases h
  · intro i id h
    simp only [program] at h
    split at h
    · cases h
      refine ⟨by simp [chooseImpl], by simp [chooseImpl, intTy, Ty.VarsIn],
        fun s u hu => by simp [chooseImpl] at hu, ?_⟩
      intro cd m ms body hc hm hb
      have he : cd = chooseClass := by
        simpa [Program.declarations, program, chooseImpl] using hc.symm
      subst cd
      simp only [chooseClass] at hm
      simp only [chooseImpl] at hb
      split at hb
      · cases hb
        split at hm
        · cases hm
          simp [Block.Scoped, Expr.Scoped, intTy, Ty.VarsIn, chooseSig]
        · contradiction
      · cases hb
    · cases h
  · intro f c k h; cases h

private theorem program_wellTyped : program.WellTyped builtins opPrim := by
  refine ⟨?_, ?_, ?_⟩
  · intro f d h
    simp only [program] at h
    split at h
    · cases h
      exact ⟨by simp [mainDef, NamesWF], Or.inr rfl,
        .B_LastDiscard (mainExpr_typed [] (some (.base .unit)) .other)⟩
    · cases h
  · intro l os h
    simp only [program] at h
    split at h
    · cases h; simp [builtins, Release.Model.builtins, stateEff, *]
    · cases h
  · intro i id h
    simp only [program] at h
    split at h
    · cases h
      refine ⟨chooseClass, rfl, ?_, ?_, ?_, ?_⟩
      · intro m; by_cases hm : m = "choose" <;> simp [chooseImpl, chooseClass, hm]
      · intro s; simp [chooseImpl, chooseClass]
      · intro m ms hm
        simp only [chooseClass] at hm
        split at hm
        · cases hm
          refine ⟨.last (.returnE intTy (.local 1)), by simp [chooseImpl, *], Or.inl trivial, ?_⟩
          exact .B_Last (.E_ReturnTail (.E_Local rfl (by
            intro b t ε h; simp [ImplDecl.methTy, chooseImpl, chooseSig, Ty.substAt, Ty.shift, intTy] at h)))
        · cases hm
      · intro s hs; simp [chooseClass] at hs
    · cases h

/-- 名前付きの操作・ハンドラ・逆順のメソッド呼び出しと実装が、性質 1 の前提を満たす。 -/
theorem program_desugar_typed :
    (desugarProgram opPrim program).WellFormed ∧
      (desugarProgram opPrim program).WellTyped builtins ∧
      (desugarProgram opPrim program).EffectsOk builtins :=
  desugar_typed program_wellFormed program_wellTyped
    (Release.Model.assumptions (desugarProgram opPrim program)).sig_scoped

/-- 表層の定理を実際の main の開始状態へ適用する。 -/
theorem program_effect_soundness :
    ∀ s, Steps (desugarProgram opPrim program) builtins
      (.run (.app (.fnRef "main" [] []) []) [] Store.empty) s →
      (∀ ev s', ¬ Step (desugarProgram opPrim program) builtins s (some ev) s') ∧ ¬ UnhandledOp s := by
  apply surface_effect_soundness program_wellFormed program_wellTyped
    (Release.Model.assumptions (desugarProgram opPrim program))
  exact ⟨mainDef, rfl, rfl, rfl, rfl, rfl, Or.inl rfl, Eff.Sub.refl _⟩

/-- if とリストの全構文の型保存を、子の計算の型付けを仮定せずに使う。 -/
example : HasTypeC (desugarProgram opPrim program) builtins StoreTy.empty [] [] none
    (desugarExpr opPrim .other (.ite (.literal (.boolean true))
      (.last (.list intTy (.cons (.literal (.integer 3)) .nil))) (.last (.list intTy .nil))))
    (.list intTy) Eff.empty := by
  have ht : HasType program.declarations builtins opPrim [] [] none .other
      (.ite (.literal (.boolean true))
        (.last (.list intTy (.cons (.literal (.integer 3)) .nil))) (.last (.list intTy .nil)))
      (.list intTy) Eff.empty := by
    simpa only [union_empty_left] using HasType.E_If (.E_Literal (l := .boolean true))
      (HasBlock.B_Last (HasType.E_List (a := intTy) (C := []) trivial (.cons (.E_Literal (l := .integer 3)) .nil)))
      (HasBlock.B_Last (HasType.E_List (a := intTy) (C := []) trivial .nil))
  exact HasType.desugar (pe := fun _ => False) program_wellFormed
    (Release.Model.assumptions (desugarProgram opPrim program)).sig_scoped ht
    (by simp [Expr.Scoped, Block.Scoped, Exprs.Scoped, intTy, Ty.VarsIn])
    (by intro i t h; cases h) (by simp)

/-- ラムダの引数名だけを変えた期待型は、型の包含を重ねても受け付けない。 -/
example : ¬ HasType program.declarations builtins opPrim [] [] none .other
    (.lam ["value"] [intTy] intTy Eff.empty (.last (.returnE intTy (.local 0))))
    (.fn ["other"] [intTy] intTy Eff.empty) Eff.empty := by
  intro h
  have hc := HasType.desugar (pe := fun _ => False) program_wellFormed
    (Release.Model.assumptions (desugarProgram opPrim program)).sig_scoped h
    (by simp [Expr.Scoped, Block.Scoped, intTy, NamesWF, Ty.VarsInList, Ty.VarsIn, Eff.RhosIn, Eff.empty])
    (by intro i t hi; cases hi) (by simp)
  obtain ⟨t, hv, hl⟩ := hc.inv_ret rfl
  obtain ⟨r, ε, _, _, hle⟩ := hv.inv_lam rfl
  have hn := (Ty.Le.fn_fn' (hle.trans hl)).1
  simp at hn

end Benitoite.Surface.Examples
