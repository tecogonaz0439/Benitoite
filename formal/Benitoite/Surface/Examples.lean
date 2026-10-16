import Benitoite.Surface.Theorems
import Benitoite.Release.Model
import Benitoite.Surface.CheckSupport

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

section DieDefinitions

-- 独立した期待コアで、入力一回・成功側の未評価・説明なしの Show と exit を確認する。
-- dict の局所参照は入力と Error の束縛の外にある。
example (op : OpPrim) :
    desugarExpr op .other
      (.tryResultDie intTy "Ok" "Error" (.local 1) "show" "Process.exit" (.local 0) none) =
      .letIn (.ret (.var 0))
        (.match (.var 0)
          [.mk [⟨.con "Ok" [.var], [0]⟩] none (.ret (.var 0)),
           .mk [⟨.con "Error" [.var], [0]⟩] none
             (.letIn (.meth (.var 3) "show" [] [] [.var 0])
               (.app (.prim "Process.exit" [intTy] []) [.const (.integer 1)]))]) := by rfl

-- 説明は元の local 2 を参照する。説明の let の下では Error が 1、辞書が 4 になる。
-- 上位辞書の経路も落とさず、外側の式の末尾位置によって展開を変えない。
example (op : OpPrim) :
    desugarExpr op .tail
      (.tryResultDie intTy "Ok" "Error" (.super (.local 1) "Show") "show" "Process.exit"
        (.local 0) (some (.local 2))) =
      .letIn (.ret (.var 0))
        (.match (.var 0)
          [.mk [⟨.con "Ok" [.var], [0]⟩] none (.ret (.var 0)),
           .mk [⟨.con "Error" [.var], [0]⟩] none
             (.letIn (.ret (.var 4))
               (.letIn (.meth (.super (.var 4) "Show") "show" [] [] [.var 1])
                 (.app (.prim "Process.exit" [intTy] []) [.const (.integer 1)])))]) := by rfl

-- None はパターン変数を増やさない。説明なしでも固定原因の計算を残す。
example (op : OpPrim) :
    desugarExpr op .other
      (.tryOptionDie intTy "Some" "None" "Process.exit" (.local 0) none) =
      .letIn (.ret (.var 0))
        (.match (.var 0)
          [.mk [⟨.con "Some" [.var], [0]⟩] none (.ret (.var 0)),
           .mk [⟨.con "None" [], []⟩] none
             (.letIn (.ret (.const (.string "expected a value, got Option.None")))
               (.app (.prim "Process.exit" [intTy] []) [.const (.integer 1)]))]) := by rfl

-- 説明内のラムダと bind の local 0 は保護し、外側の String の参照だけ一つ移す。
example (op : OpPrim) :
    desugarExpr op .other
      (.tryOptionDie intTy "Some" "None" "Process.exit" (.local 0)
        (some (.call
          (.lam ["value"] [intTy] (.base .string) Eff.empty
            (.bind .bind intTy (.local 0) (.last (.local 3))))
          [none] [0] (.cons (.literal (.integer 7)) .nil)))) =
      .letIn (.ret (.var 0))
        (.match (.var 0)
          [.mk [⟨.con "Some" [.var], [0]⟩] none (.ret (.var 0)),
           .mk [⟨.con "None" [], []⟩] none
             (.letIn
               (.letIn (.ret (.lam ["value"] [intTy]
                 (.letIn (.ret (.var 0)) (.ret (.var 4)))))
                 (.letIn (.ret (.const (.integer 7))) (.app (.var 1) [.var 0])))
               (.letIn (.ret (.const (.string "expected a value, got Option.None")))
                 (.app (.prim "Process.exit" [intTy] []) [.const (.integer 1)])))]) := by rfl

-- 型と値の範囲は、説明・入力・辞書・成功型のどれか一つが範囲外でも拒否する。
-- 正の対照は、同じ元の環境で説明と辞書を参照できることも確かめる。
example :
    (Expr.tryResultDie (.tvar 0) "Ok" "Error" (.local 1) "show" "Process.exit"
      (.local 0) (some (.local 1))).Scoped 1 (fun _ => False) 2 ∧
    ¬ (Expr.tryResultDie (.tvar 0) "Ok" "Error" (.local 1) "show" "Process.exit"
      (.local 0) (some (.local 2))).Scoped 1 (fun _ => False) 2 ∧
    ¬ (Expr.tryResultDie (.tvar 0) "Ok" "Error" (.local 2) "show" "Process.exit"
      (.local 0) none).Scoped 1 (fun _ => False) 2 ∧
    ¬ (Expr.tryOptionDie (.tvar 0) "Some" "None" "Process.exit"
      (.local 2) none).Scoped 1 (fun _ => False) 2 ∧
    ¬ (Expr.tryOptionDie (.tvar 1) "Some" "None" "Process.exit"
      (.local 0) none).Scoped 1 (fun _ => False) 2 ∧
    ¬ (Expr.tryOptionDie (.tvar 0) "Some" "None" "Process.exit"
      (.local 0) (some (.local 2))).Scoped 1 (fun _ => False) 2 := by
  simp [Expr.Scoped, DictEv.Scoped, Ty.VarsIn]

-- 子にしかないエフェクト原子と、辞書の型引数の原子も収集範囲から落とさない。
private def effectfulTy : Ty := .fn [] [] intTy (Eff.single "Hidden")
private def annotated : Expr := .returnE effectfulTy .unit
example :
    (Expr.tryOptionDie intTy "Some" "None" "Process.exit" .unit none).AtomsIn [] ∧
    ¬ (Expr.tryOptionDie intTy "Some" "None" "Process.exit"
      annotated none).AtomsIn [] ∧
    ¬ (Expr.tryOptionDie intTy "Some" "None" "Process.exit"
      .unit (some annotated)).AtomsIn [] ∧
    ¬ (Expr.tryResultDie intTy "Ok" "Error" (.impl "Show" [effectfulTy] []) "show" "Process.exit"
      .unit none).AtomsIn [] ∧
    ¬ (Expr.tryResultDie intTy "Ok" "Error" (.local 0) "show" "Process.exit"
      .unit (some annotated)).AtomsIn [] ∧
    ¬ (Expr.tryOptionDie effectfulTy "Some" "None" "Process.exit"
      .unit none).AtomsIn [] := by
  simp [Expr.AtomsIn, DictEv.AtomsIn, DictEvs.AtomsIn, Tys.AtomsIn, Ty.AtomsIn,
    Eff.AtomsIn, effectfulTy, annotated, intTy, Eff.single]

end DieDefinitions

section DieTyping

private def dieShowSig : MethSig :=
  { tparams := [], neffs := 0, names := ["x"], params := [.tvar 0],
    ret := .base .string, eff := Eff.empty }
private def dieShowClass : ClassDecl :=
  { supers := [], methods := fun m => if m = "show" then some dieShowSig else none }
private def dieProgram : Program :=
  { defs := fun _ => none,
    cons := fun c =>
      if c = "Ok" then some ⟨"Result", 2, [.tvar 0]⟩
      else if c = "Error" then some ⟨"Result", 2, [.tvar 1]⟩
      else if c = "Some" then some ⟨"Option", 1, [.tvar 0]⟩
      else if c = "None" then some ⟨"Option", 1, []⟩ else none,
    ops := fun _ => none, effects := fun _ => none,
    classes := fun cl => if cl = "Show" then some dieShowClass else none,
    impls := fun _ => none }
private def dieCtors : DataName → List ConName
  | "Result" => ["Ok", "Error"] | "Option" => ["Some", "None"] | _ => []
private theorem dieCtors_complete : CtorsComplete dieProgram.declarations.patternProgram dieCtors := by
  intro c cd h
  simp only [Program.declarations, Declarations.patternProgram, dieProgram] at h
  split at h
  · cases h; simp [dieCtors, *]
  · split at h
    · cases h; simp [dieCtors, *]
    · split at h
      · cases h; simp [dieCtors, *]
      · split at h
        · cases h; simp [dieCtors, *]
        · cases h
private def dieExitSig : PrimSig :=
  { tparams := [{}], neffs := 0, names := ["code"], params := [intTy], ret := .tvar 0,
    eff := Eff.single "Process.Exit", kind := .exit, opEff := some "Process.Exit",
    admits := fun _ ts => ts.length = 1 }
private def dieBuiltins : Builtins :=
  { builtins with
    sig := fun b => if b = "exit" then some dieExitSig else none
    effects := fun l => if l = "Process.Exit" then some ["exit"] else none }
private theorem dieExit_ok (C : List TParam) (t : Ty) : DieExitOk dieBuiltins C "exit" t := by
  refine ⟨dieExitSig, rfl, rfl, rfl, rfl, rfl, ?_, by rfl, ?_⟩
  · simp [dieExitSig, NamesWF]
  · simp [dieExitSig, fnTy, Ty.subst, Ty.substAt, Ty.shift_zero, intTy, Eff.substRho_nil]
private def errorTy : Ty := .opaque "ErrorWithoutShowImpl"
private def resultTy : Ty := .data "Result" [intTy, errorTy]
private def optionTy : Ty := .data "Option" [intTy]
private def resultEnv : List (Option Ty) :=
  [some resultTy, some (.dict "Show" errorTy), some (.base .string)]
private def resultDie : Expr :=
  .tryResultDie intTy "Ok" "Error" (.local 1) "show" "exit" (.local 0) (some (.local 2))

-- R は None でも Result/Option 以外でもよい。エラーの表示は受け取った辞書を使う。
private theorem resultDie_typed (R : Option Ty) (pos : Position) :
    HasType dieProgram.declarations dieBuiltins opPrim [] resultEnv R pos resultDie
      intTy (Eff.single "Process.Exit") := by
  apply HasType.E_Sub (ε := Eff.union Eff.empty (Eff.single "Process.Exit")) _ (.refl _)
    (by rw [union_empty_left]; exact .refl _)
  apply HasType.E_TryResultDie (cdo := ⟨"Result", 2, [.tvar 0]⟩)
    (cde := ⟨"Result", 2, [.tvar 1]⟩) rfl rfl rfl rfl rfl rfl rfl
    (.E_Local rfl (by intro _ _ _ h; cases h))
  · exact CheckTools.tryResultExhaustive_sound dieCtors_complete (by decide)
  · exact ⟨"Show", dieShowClass, dieShowSig, .local rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩
  · exact dieExit_ok [] intTy
  · intro m hm; cases hm
    exact .E_Local rfl (by intro _ _ _ h; cases h)

-- Option の説明なしには辞書が要らず、継続がある環境でも処置自身は外へ脱出しない。
example (R : Option Ty) : HasType dieProgram.declarations dieBuiltins opPrim []
    [some optionTy, some (.cont intTy intTy Eff.empty)] R .other
    (.tryOptionDie intTy "Some" "None" "exit" (.local 0) none)
    intTy (Eff.union Eff.empty (Eff.single "Process.Exit")) := by
  apply HasType.E_TryOptionDie (cds := ⟨"Option", 1, [.tvar 0]⟩)
    (cdn := ⟨"Option", 1, []⟩) rfl rfl rfl rfl rfl rfl rfl
    (.E_Local rfl (by intro _ _ _ h; cases h))
  · exact CheckTools.tryOptionExhaustive_sound dieCtors_complete (by decide)
  · exact dieExit_ok [] intTy
  · intro m hm; cases hm

private theorem dieProgram_wf : dieProgram.WellFormed := by
  refine ⟨(fun _ _ h => by cases h), (fun _ _ h => by cases h), ?_,
    (fun _ _ h => by cases h), (fun _ _ _ h => by cases h), (fun _ _ h => by cases h), ?_,
    (fun _ _ h => by cases h), (fun _ _ _ h => by cases h)⟩
  · intro c cd h
    simp only [dieProgram] at h
    split at h
    · cases h; simp [ConDecl.Scoped, Ty.VarsInList, Ty.VarsIn]
    · split at h
      · cases h; simp [ConDecl.Scoped, Ty.VarsInList, Ty.VarsIn]
      · split at h
        · cases h; simp [ConDecl.Scoped, Ty.VarsInList, Ty.VarsIn]
        · split at h
          · cases h; trivial
          · cases h
  · intro cl cd h m ms hm
    simp only [dieProgram] at h
    split at h
    · cases h
      simp only [dieShowClass] at hm
      split at hm
      · cases hm; simp [MethSig.Scoped, dieShowSig, NamesWF, Ty.VarsInList, Ty.VarsIn, Eff.RhosIn, Eff.empty]
      · cases hm
    · cases h
private theorem dieSigs_scoped : ∀ b s, dieBuiltins.sig b = some s → s.Scoped := by
  intro b s h
  simp only [dieBuiltins] at h
  split at h
  · cases h
    simp [PrimSig.Scoped, PrimSig.ntys, dieExitSig, intTy, NamesWF, Ty.VarsInList, Ty.VarsIn, Eff.RhosIn, Eff.single]
  · cases h

-- 型付けの導出から全体の型保存を実際に呼び、説明の自由変数と辞書の移動を検査する。
example : HasTypeC (desugarProgram opPrim dieProgram) dieBuiltins StoreTy.empty [] resultEnv
    (some (.base .boolean)) (desugarExpr opPrim .other resultDie) intTy (Eff.single "Process.Exit") := by
  refine HasType.desugar (view := closedView) (pe := fun _ => True) dieProgram_wf dieSigs_scoped
    (resultDie_typed _ _) (by simp [resultDie, resultEnv, Expr.Scoped, DictEv.Scoped, intTy, Ty.VarsIn]) ?_ (by intro r h; cases h; trivial)
  change EnvClean 0 [some resultTy, some (.dict "Show" errorTy), some (.base .string)]
  apply EnvClean.cons (by trivial)
  apply EnvClean.cons (by trivial)
  apply EnvClean.cons (by trivial)
  intro i a h; cases h

-- 説明の内側の明示 lambda は自分の戻り先を作り、外側の継続は捕えない。
example (Γ : List (Option Ty)) :
    HasType dieProgram.declarations dieBuiltins opPrim [] (hideConts Γ) none .other
      (.call (.lam [] [] (.base .string) Eff.empty
        (.last (.returnE (.base .string) (.literal (.string "reason"))))) [] [] .nil)
      (.base .string) (Eff.union Eff.empty (Eff.union Eff.empty Eff.empty)) := by
  exact .E_Call (.E_Lam (by simp [NamesWF]) (Or.inl trivial)
    (.B_Last (.E_ReturnTail .E_Literal)))
    ⟨by simp [NamesWF], by simp, by simp, Or.inl ⟨rfl, rfl⟩⟩ .nil

-- Show のないエラーの伝播に表示制約を加えない。
example : HasType dieProgram.declarations dieBuiltins opPrim [] [some resultTy]
    (some (.data "Result" [.base .unit, errorTy])) .other
    (.tryResult [.base .unit, errorTy] "Ok" "Error" (.local 0)) intTy Eff.empty := by
  apply HasType.E_TryResult (cdo := ⟨"Result", 2, [.tvar 0]⟩)
    (cde := ⟨"Result", 2, [.tvar 1]⟩) rfl rfl rfl rfl rfl rfl rfl rfl
    (.E_Local rfl (by intro _ _ _ h; cases h))
  exact CheckTools.tryResultExhaustive_sound dieCtors_complete (by decide)

-- R=None では直接の return を型付けできず、型の包含でも隠せない。
private theorem noReturnWithoutTarget {D B op C Γ R pos e t ε}
    (h : HasType D B op C Γ R pos e t ε) :
    ∀ a value, e = .returnE a value → R ≠ none := by
  match h with
  | .E_ReturnTail _ => intro _ _ _ hn; cases hn
  | .E_ReturnOther _ _ => intro _ _ _ hn; cases hn
  | .E_Sub h _ _ => exact noReturnWithoutTarget h
  | .E_Local .. => intro _ _ he; cases he
  | .E_Const .. => intro _ _ he; cases he
  | .E_Fun .. => intro _ _ he; cases he
  | .E_FunDicts .. => intro _ _ he; cases he
  | .E_MethName .. => intro _ _ he; cases he
  | .E_Prim .. => intro _ _ he; cases he
  | .E_Op .. => intro _ _ he; cases he
  | .E_NullCon .. => intro _ _ he; cases he
  | .E_ConValue .. => intro _ _ he; cases he
  | .E_Literal .. => intro _ _ he; cases he
  | .E_NegInt .. => intro _ _ he; cases he
  | .E_NegFloat .. => intro _ _ he; cases he
  | .E_NegDecimal .. => intro _ _ he; cases he
  | .E_NegInteger8 .. => intro _ _ he; cases he
  | .E_NegInteger16 .. => intro _ _ he; cases he
  | .E_NegInteger32 .. => intro _ _ he; cases he
  | .E_NegFloat32 .. => intro _ _ he; cases he
  | .E_Unit .. => intro _ _ he; cases he
  | .E_Paren .. => intro _ _ he; cases he
  | .E_Record .. => intro _ _ he; cases he
  | .E_RecordUpdate .. => intro _ _ he; cases he
  | .E_ConCall .. => intro _ _ he; cases he
  | .E_Call .. => intro _ _ he; cases he
  | .E_PipeCall .. => intro _ _ he; cases he
  | .E_PipeConCall .. => intro _ _ he; cases he
  | .E_PipeConValue .. => intro _ _ he; cases he
  | .E_PipeApply .. => intro _ _ he; cases he
  | .E_PartialCall .. => intro _ _ he; cases he
  | .E_PartialCon .. => intro _ _ he; cases he
  | .E_Binary .. => intro _ _ he; cases he
  | .E_Neg .. => intro _ _ he; cases he
  | .E_Not .. => intro _ _ he; cases he
  | .E_And .. => intro _ _ he; cases he
  | .E_Or .. => intro _ _ he; cases he
  | .E_List .. => intro _ _ he; cases he
  | .E_ListSpread .. => intro _ _ he; cases he
  | .E_Interpolation .. => intro _ _ he; cases he
  | .E_Lam .. => intro _ _ he; cases he
  | .E_If .. => intro _ _ he; cases he
  | .E_ElseIf .. => intro _ _ he; cases he
  | .E_IfOnly .. => intro _ _ he; cases he
  | .E_Match .. => intro _ _ he; cases he
  | .E_TryResult .. => intro _ _ he; cases he
  | .E_TryOption .. => intro _ _ he; cases he
  | .E_TryResultDie .. => intro _ _ he; cases he
  | .E_TryOptionDie .. => intro _ _ he; cases he
  | .E_With .. => intro _ _ he; cases he
  | .E_Lazy .. => intro _ _ he; cases he
  | .E_Handle .. => intro _ _ he; cases he
  | .E_Resume .. => intro _ _ he; cases he

example : ¬ HasType dieProgram.declarations dieBuiltins opPrim [] (hideConts resultEnv) none .other
    (.returnE (.base .string) (.literal (.string "reason"))) (.base .string) Eff.empty := by
  intro h
  exact noReturnWithoutTarget h _ _ rfl rfl

-- 外側の継続への resume は説明の環境に残らず、包含でも利用可能にならない。
private theorem resume_requires_binding {D B op C Γ R pos e t ε}
    (h : HasType D B op C Γ R pos e t ε) :
    ∀ k value, e = .resume k value → Γ[k]? ≠ some none := by
  match h with
  | .E_Resume hk _ => intro _ _ he hn; cases he; rw [hk] at hn; cases hn
  | .E_Sub h _ _ => exact resume_requires_binding h
  | .E_Local .. => intro _ _ he; cases he
  | .E_Const .. => intro _ _ he; cases he
  | .E_Fun .. => intro _ _ he; cases he
  | .E_FunDicts .. => intro _ _ he; cases he
  | .E_MethName .. => intro _ _ he; cases he
  | .E_Prim .. => intro _ _ he; cases he
  | .E_Op .. => intro _ _ he; cases he
  | .E_NullCon .. => intro _ _ he; cases he
  | .E_ConValue .. => intro _ _ he; cases he
  | .E_Literal .. => intro _ _ he; cases he
  | .E_NegInt .. => intro _ _ he; cases he
  | .E_NegFloat .. => intro _ _ he; cases he
  | .E_NegDecimal .. => intro _ _ he; cases he
  | .E_NegInteger8 .. => intro _ _ he; cases he
  | .E_NegInteger16 .. => intro _ _ he; cases he
  | .E_NegInteger32 .. => intro _ _ he; cases he
  | .E_NegFloat32 .. => intro _ _ he; cases he
  | .E_Unit .. => intro _ _ he; cases he
  | .E_Paren .. => intro _ _ he; cases he
  | .E_Record .. => intro _ _ he; cases he
  | .E_RecordUpdate .. => intro _ _ he; cases he
  | .E_ConCall .. => intro _ _ he; cases he
  | .E_Call .. => intro _ _ he; cases he
  | .E_PipeCall .. => intro _ _ he; cases he
  | .E_PipeConCall .. => intro _ _ he; cases he
  | .E_PipeConValue .. => intro _ _ he; cases he
  | .E_PipeApply .. => intro _ _ he; cases he
  | .E_PartialCall .. => intro _ _ he; cases he
  | .E_PartialCon .. => intro _ _ he; cases he
  | .E_Binary .. => intro _ _ he; cases he
  | .E_Neg .. => intro _ _ he; cases he
  | .E_Not .. => intro _ _ he; cases he
  | .E_And .. => intro _ _ he; cases he
  | .E_Or .. => intro _ _ he; cases he
  | .E_List .. => intro _ _ he; cases he
  | .E_ListSpread .. => intro _ _ he; cases he
  | .E_Interpolation .. => intro _ _ he; cases he
  | .E_Lam .. => intro _ _ he; cases he
  | .E_If .. => intro _ _ he; cases he
  | .E_ElseIf .. => intro _ _ he; cases he
  | .E_IfOnly .. => intro _ _ he; cases he
  | .E_Match .. => intro _ _ he; cases he
  | .E_ReturnTail .. => intro _ _ he; cases he
  | .E_ReturnOther .. => intro _ _ he; cases he
  | .E_TryResult .. => intro _ _ he; cases he
  | .E_TryOption .. => intro _ _ he; cases he
  | .E_TryResultDie .. => intro _ _ he; cases he
  | .E_TryOptionDie .. => intro _ _ he; cases he
  | .E_With .. => intro _ _ he; cases he
  | .E_Lazy .. => intro _ _ he; cases he
  | .E_Handle .. => intro _ _ he; cases he

example : ¬ HasType dieProgram.declarations dieBuiltins opPrim []
    (hideConts [some (.cont intTy (.base .string) Eff.empty)]) none .other
    (.resume 0 (.literal (.integer 1))) (.base .string) Eff.empty := by
  intro h
  exact resume_requires_binding h _ _ rfl rfl

end DieTyping

end Benitoite.Surface.Examples
