import Benitoite.Release.Refinement.ProgramWellFormed
/-! 型構成子のクラス、依存する宣言、handler の下の escape、変異で問うた辞書の kind。 -/
namespace Benitoite.Release.Refinement.RVW3
open Benitoite.Release.Refinement
noncomputable section

def unit : Ty := .base .unit
def int : Ty := .base .integer

/-! ## 型構成子を引数にとるクラス（`implement Functor[List]`） -/
-- 自身の型パラメータ0、クラス引数1（F[_]）。
def fmapLike : MethSig := ⟨[⟨({} : TParam), .value⟩], 0, ["x"], [.tapp 1 [.tvar 0]], .tapp 1 [.tvar 0], Eff.empty⟩
def functorC : ClassDecl := ⟨.constructor 1, [], fun m => if m = "same" then some fmapLike else none⟩
def listImpl : ImplDecl := ⟨[], [], "Functor", .ctor .list, fun _ => none, fun m => if m = "same" then some (.ret (.var 0)) else none⟩
def hkProgram : Program := {
  defs := fun _ => none, cons := fun _ => none, ops := fun _ => none, effects := fun _ => none
  classes := fun c => if c = "Functor" then some functorC else none
  impls := fun i => if i = "L" then some listImpl else none }

theorem hk_contract : Tel.shiftV 0 0 (Tel.bind (typeEnvAt 1 [.ctor .list] []) fmapLike.tel) =
    .param "x" (.list (.tvar 0)) (.done (.list (.tvar 0)) Eff.empty) := by
  simp [fmapLike, MethSig.tel, signatureTel, Tel.bind, Tel.rawBind, typeEnvAt, Ty.rawBind, rawBindTys, rawApply, SubstEnv.shiftTypes, shiftTypes, Tel.norm, Ty.norm, Eff.norm, Eff.rawBind, rowFails, Ty.normTys, Eff.empty, Tel.shiftV, Ty.shiftV, Eff.shiftV, shiftVTys]
  funext a
  cases a with
  | name l ix => cases ix <;> simp [substAtoms, instAtoms]
  | rho i => simp [substAtoms, instAtoms]

theorem hk_impl (B : Builtins) : listImpl.WellTyped hkProgram B := by
  refine ⟨functorC, by simp [hkProgram, listImpl], ?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro m; by_cases h : m = "same" <;> simp [listImpl, functorC, h]
  · intro s; simp [listImpl, functorC]
  · simp [Ty.HasKind, TyCon.arity, functorC, listImpl]
  · intro a ha; simp [ImplDecl.dictTys, listImpl] at ha
  · intro m ms hm
    simp only [functorC] at hm
    split at hm <;> simp_all only [Option.some.injEq, reduceCtorEq]
    subst ms
    refine ⟨.ret (.var 0), by simp [listImpl, *], by simp [NamesWF, fmapLike], ?_⟩
    have hd : listImpl.dictTys = [] := rfl
    simp only [hd, List.length_nil, List.map_nil]
    have hl : (fmapLike.tparams.length) = 1 := rfl
    have ht : listImpl.target = .ctor .list := rfl
    rw [hl, ht, hk_contract]
    exact .param (.done (.C_Return (.V_Var rfl (by intro b t e h; cases h))))
  · intro s hs; simp [functorC] at hs

theorem hk_scoped : functorC.Scoped hkProgram := by
  intro m ms hm
  simp only [functorC] at hm
  split at hm <;> simp_all only [Option.some.injEq, reduceCtorEq]
  subst ms
  refine ⟨by simp [NamesWF, fmapLike], ?_⟩
  have ha : Ty.Annotation hkProgram [{}, {}] [] (.dependentFn fmapLike.tel) := by
    constructor <;> simp [Ty.WF, Tel.WF, Eff.WF, Ty.WFList, Eff.Canonical, Eff.empty, Eff.norm, Ty.normTys, Ty.Sorted, Tel.Sorted, sortedEff, sortedTys, Ty.Declared, Tel.Declared, declaredEff, declaredTys, signatureTel, fmapLike, MethSig.tel]
  refine ⟨⟨ha.wf, ?_, ?_⟩, ?_, ?_, ha⟩ <;> simp [Ty.SourceScoped, Ty.RangesScoped, Tel.RangesScoped, Eff.RangesScoped, rangesScopedTypes, RangeIx.WF, Ty.WF, Tel.WF, Eff.WF, Ty.WFList, Eff.Canonical, Eff.empty, Eff.norm, Ty.normTys, Ty.Sorted, Tel.Sorted, sortedEff, sortedTys, Ty.Declared, Tel.Declared, declaredEff, declaredTys, signatureTel, Eff.RowsIn, Ty.RowsInList, Tel.RowsIn, Ty.RowsIn, Ty.HasKind, kindsTel, kindsEff, kindsList, fmapLike, MethSig.tel, functorC]

theorem hk_impl_scoped : listImpl.Scoped hkProgram := by
  refine ⟨by simp [listImpl], ⟨by simp [Ty.WF, listImpl], trivial, trivial⟩, ?_, ?_, ?_, ?_⟩
  · constructor <;> simp [Ty.WF, Ty.Sorted, Ty.Declared, listImpl]
  · intro a ha; simp [ImplDecl.dictTys, listImpl] at ha
  · intro s u h; simp [listImpl] at h
  · intro cd m ms body hc hm hb
    simp [hkProgram, listImpl] at hc
    subst cd
    simp only [functorC] at hm
    split at hm <;> simp_all only [Option.some.injEq, reduceCtorEq]
    subst ms
    simp [listImpl] at hb
    subst body
    simp [Comp.SourceScoped, Val.SourceScoped, listImpl, fmapLike, ImplDecl.dictTys]

/-! ## 依存する宣言 `f(x: Integer, y: Integer{self == x}) -> Integer{self == x}` -/
-- y の注釈は x の下: self=0, x=1。結果は x, y の下: self=0, y=1, x=2。
def depDef : Def := ⟨[], 0, ["x", "y"], [int, .refined int (.eq (.var 0) (.var 1))],
  .refined int (.eq (.var 0) (.var 2)), Eff.empty, .ret (.var 0)⟩
def P0 : Program := {
  defs := fun _ => none, cons := fun _ => none, ops := fun _ => none, effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none }

theorem dep_body (B : Builtins) : TelBodyTy P0 B StoreTy.empty (QTel depDef.tel) [] [] [] depDef.tel depDef.body := by
  refine .param (.param (.done (.C_Return (.V_Var ?_ ?_))))
  · simp [depDef, Ctx.extend, Ty.shiftV, int, predBind, termBind, termBind?, shiftIndex]
  · intro b t e h; simp [depDef, Ty.core, int] at h
end
end Benitoite.Release.Refinement.RVW3
