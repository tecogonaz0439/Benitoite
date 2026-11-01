import Benitoite.Release.Refinement.ProgramWellFormed
/-! 辞書引数を読むメソッド本体、行を持つ署名、Q の接続の確認。 -/
namespace Benitoite.Release.Refinement.RVW
open Benitoite.Release.Refinement
noncomputable section

def unit : Ty := .base .unit
-- クラス引数は番号1。自身の型パラメータ0。結果は親クラスの辞書。
def getSig : MethSig := ⟨[⟨({} : TParam), .value⟩], 0, ["x"], [.tvar 1], .dict "Parent" (.tvar 1), Eff.empty⟩
def parentC : ClassDecl := ⟨.value, [], fun _ => none⟩
def klass : ClassDecl := ⟨.value, [], fun m => if m = "get" then some getSig else none⟩
def mkImpl (body : Comp) : ImplDecl := ⟨[({} : TParam)], [("Parent", 0)], "Class", .tvar 0,
  fun _ => none, fun m => if m = "get" then some body else none⟩
def program (body : Comp) : Program := {
  defs := fun _ => none, cons := fun _ => none, ops := fun _ => none, effects := fun _ => none
  classes := fun c => if c = "Class" then some klass else if c = "Parent" then some parentC else none
  impls := fun i => if i = "I" then some (mkImpl body) else none }

theorem contract (b) : Tel.shiftV (mkImpl b).dictTys.length 0
      (Tel.bind (typeEnvAt getSig.tparams.length [(mkImpl b).target] []) getSig.tel) =
      .param "x" (.tvar 1) (.done (.dict "Parent" (.tvar 1)) Eff.empty) := by
  simp [mkImpl, getSig, MethSig.tel, signatureTel, Tel.bind, Tel.rawBind, typeEnvAt, Ty.rawBind, shiftTypes, Tel.norm, Ty.norm, Eff.norm, Eff.rawBind, rowFails, Ty.normTys, Eff.empty, Tel.shiftV, Ty.shiftV, Eff.shiftV, shiftVTys, ImplDecl.dictTys]
  funext a
  cases a with
  | name l ix => cases ix <;> simp [substAtoms, instAtoms]
  | rho i => simp [substAtoms, instAtoms]

theorem dictctx (b) : bindParams [] ((mkImpl b).dictTys.map (Ty.shift getSig.tparams.length 0)) =
    [some (.dict "Parent" (.tvar 1))] := by
  simp [bindParams, mkImpl, ImplDecl.dictTys, getSig, Ty.shift, Ty.bind, Ty.rawBind, SubstEnv.shiftTypes, Ty.norm, Ty.shiftV, shiftIndex]

/-- 辞書は Γ の番号1にあり、メソッドの型代入の後の結果型と一致する。 -/
theorem dict_body_typed (B : Builtins) :
    TelBodyTy (program (.ret (.var 1))) B StoreTy.empty (fun _ => False) ([{}, {}]) 
      [some (.dict "Parent" (.tvar 1))] []
      (.param "x" (.tvar 1) (.done (.dict "Parent" (.tvar 1)) Eff.empty)) (.ret (.var 1)) := by
  refine .param (.done (.C_Return (.V_Var ?_ ?_)))
  · simp [Ctx.extend, Ty.shiftV]
  · intro b t e h; cases h

/-- 入口全体でも同じ本体が通る。 -/
theorem impl_wellTyped (B : Builtins) : (mkImpl (.ret (.var 1))).WellTyped (program (.ret (.var 1))) B := by
  refine ⟨klass, by simp [program, mkImpl], ?_, ?_, rfl, ?_, ?_, ?_⟩
  · intro m; by_cases h : m = "get" <;> simp [mkImpl, klass, h]
  · intro s; simp [mkImpl, klass]
  · intro a ha
    simp [ImplDecl.dictTys, mkImpl] at ha
    subst a
    constructor <;> simp [Ty.WF, Ty.Sorted, Ty.Declared, mkImpl]
  · intro m ms hm
    simp only [klass] at hm
    split at hm <;> simp_all only [Option.some.injEq, reduceCtorEq]
    subst ms
    refine ⟨.ret (.var 1), by simp [mkImpl, *], by simp [NamesWF, getSig], ?_⟩
    rw [contract, dictctx]
    have := dict_body_typed B
    have hq : QTel (.param "x" (.tvar 1) (.done (.dict "Parent" (.tvar 1)) Eff.empty)) = fun _ => False := by
      funext i; simp [QTel, QTy, QEff, Eff.empty, Qempty, QTys]
    simpa [hq, List.map_append, TParamDecl.constraints, getSig, mkImpl] using this
  · intro s hs; simp [klass] at hs

-- 行変数は es=[] の型代入で保たれる。
theorem row_kept : Tel.bind (typeEnvAt 1 [.tvar 0] []) (.done (.tvar 0) (Eff.row 0)) = .done (.tvar 0) (Eff.row 0) := by
  simp [Tel.bind, Tel.rawBind, Ty.rawBind, typeEnvAt, Eff.rawBind, rowFails, Tel.norm, Ty.norm, Eff.norm, Eff.row, Ty.normTys, shiftTypes]
  funext a; cases a with
  | name l ix => cases ix <;> simp [substAtoms, instAtoms]
  | rho i => simp [substAtoms, instAtoms]

-- 反例の入力: 対象型が行を持つと、代入後の QTel は代入前の Qsig より広い。
def failRow : Eff := .mk (fun a => match a with | .rho i => decide (i = 0) | _ => false) [unit]
def rowTarget : Ty := .fn [] [] unit failRow
def plain : MethSig := ⟨[], 1, ["x"], [.tvar 0], unit, Eff.empty⟩
theorem qsig_empty : ¬ Qsig plain.params plain.ret plain.eff 0 := by
  simp [Qsig, plain, QTys, QTy, QEff, Eff.empty, Qempty, unit]
theorem qtel_grows :
    QTel (Tel.shiftV 0 0 (Tel.bind (typeEnvAt 0 [rowTarget] []) plain.tel)) 0 := by
  simp [SubstEnv.shiftTypes, plain, MethSig.tel, signatureTel, Tel.bind, Tel.rawBind, typeEnvAt, Ty.rawBind, shiftTypes, rowTarget, Tel.norm, Tel.shiftV, QTel, QTy, Ty.norm, Ty.shiftV, Ty.normTys, Eff.norm, QTys, QEff, failRow, unit, Eff.shiftV]
end
end Benitoite.Release.Refinement.RVW
