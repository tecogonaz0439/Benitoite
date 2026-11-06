import Benitoite.Release.Refinement.Surface.CheckAccept
import Benitoite.Release.Refinement.StandardModelApplication

/-! # 表層のプログラムの開始と主定理

表層の整形式と性質1から、追加宣言の義務と開始の型付けを供給する
（設計書 01-12「確かめる性質」、07-04「01-12 との対応」）。
-/
namespace Benitoite.Release.Refinement.Surface
noncomputable section

/-- 性質1の三検査から、追加宣言の十一の義務を同じ組込みの表で取り出す。 -/
theorem desugar_additions {p : Program} {B : Builtins} {op : OpPrim}
    (base : Refinement.Program) (hwf : p.WellFormed) (hwt : p.WellTyped B op)
    (hA : Builtins.ValueAssumptions (desugarProgram op p) B) :
    Refinement.Program.Additions base (desugarProgram op p) B := by
  obtain ⟨hf, ht, he⟩ := desugar_typed hwf hwt hA
  exact ⟨fun f d _ hd => ⟨ht.defs f d hd, hf.defs f d hd⟩,
    fun i id _ hi => ⟨ht.impls i id hi, hf.impls i id hi⟩,
    fun c cd _ hc => hf.cons c cd hc, fun o od _ ho => hf.ops o od ho,
    fun c cd _ hc => hf.classes c cd hc, hf.metadata,
    fun d info _ hi => ht.variance.1 d info hi,
    fun c cd _ hc => ht.variance.2 c cd hc,
    fun l os o _ hl ho => he.1 l os o hl ho,
    fun o od _ ho => he.2.1 o od ho, fun l os _ hl => he.2.2 l os hl⟩

/-- 入口で許す結果の型。 -/
def MainReturn (a : Ty) : Prop :=
  a = .base .unit ∨ a = .data "Result" [.base .unit, .base .string]

/-- main は型・行・範囲パラメータと実引数を持たず、宣言した効果 ε で始める。 -/
def Program.HasMain (p : Program) (ε : Eff) : Prop :=
  ∃ d, p.defs "main" = some d ∧ d.tparams = [] ∧ d.neffs = 0 ∧ d.rangeParams = [] ∧
    d.coreNames = [] ∧ d.coreParams = [] ∧ MainReturn d.ret ∧ d.eff = ε

/-- main を呼ぶ開始の閉包。 -/
def mainClosure : Closure := Closure.pure (.app (.fnRef "main" [] [] []) [])

/-- main の宣言の形と整形式から、実引数なしの開始の呼出しを型付ける。 -/
theorem main_typed_realized {p : Program} {P : Refinement.Program} {B : Builtins} {op : OpPrim} {ε : Eff}
    (hwf : p.WellFormed) (hmain : p.HasMain ε)
    (hS : p.declarations.core.SameTypes P)
    (hdefs : ∀ f d, (desugarProgram op p).defs f = some d → P.defs f = some d) :
    ∃ a, MainReturn a ∧ Ty.Annotation P [] [] (.dependentFn (.done a ε)) ∧ HasTypeC P B StoreTy.empty [] [] [] none
      (.app (.fnRef "main" [] [] []) []) a ε := by
  obtain ⟨d, hd, ht, he, hr, hn, hp, hret, rfl⟩ := hmain
  obtain ⟨hnames, hscope, _⟩ := hwf.defs "main" d hd
  have hs := signatureScopedR_sameTypes hscope hS
  have ha : Ty.Annotation P [] [] (.dependentFn d.toFunDecl.tel) := by
    simpa only [hr, ht, Ty.annotationR_nil] using hs.2.2.2
  have htel : d.toFunDecl.tel = .done d.ret d.eff := by
    simp [FunDecl.tel, hn, hp, signatureTel]
  have hrows : Tel.RowsIn (· < 0) d.toFunDecl.tel := by simpa only [he] using hs.2.1
  have had : Admissible B [] 0 [] 0 (Qsig [] d.ret d.eff) Qempty [] [] d.eff := by
    refine ⟨⟨rfl, ?_⟩, ?_, rfl, ?_, ?_, ?_, ?_⟩
    · intro i a param hi; cases hi
    · intro a h; cases h
    · intro e h; cases h
    · exact (htel ▸ hrows).2
    · intro i hi
      apply CheckAdmissible.qTel_scoped d.toFunDecl.tel hrows i
      simpa [htel, Qsig, QTys, QTel, Qempty] using hi
    · intro i hi
      have hfalse := CheckAdmissible.qTel_scoped d.toFunDecl.tel hrows i
        (by simpa [htel, Qsig, QTys, QTel, Qempty] using hi)
      exact False.elim (Nat.not_lt_zero i hfalse)
  have hinst : instantiatedTel d.toFunDecl.tel [] [] = d.toFunDecl.tel :=
    (Tel.substAt_nil_of_wf [] d.toFunDecl.tel ha.wf).trans (by
      rw [htel]
      have hnormal : d.ret.Normal := by rcases hret with h | h <;> rw [h] <;> rfl
      exact congr (congrArg Tel.done hnormal) (htel ▸ ha.wf).2.2)
  have hsig : SignatureInstance P [] [] d.toFunDecl.tel [] [] [] :=
    ⟨ha.wf, (by intro a h; cases h), ⟨rfl, by intro i a k h; cases h⟩,
      (by intro e h; cases h), (by intro e h; cases h), (by rw [hinst]; exact ha)⟩
  have hlookup : P.defs "main" = some (desugarDef op d) := by
    apply hdefs
    simp [desugarProgram, Program.lookupFun, hd]
  have hf := HasTypeVQ.fun_empty (B := B) (ts := []) (es := []) (Ψ := StoreTy.empty) (Q := Qempty) (C := []) (Γ := []) (Φ := [])
    hlookup hnames (by simpa [desugarDef] using hr) (by simpa [desugarDef, ht, hp, he, TypeCtx.constraints] using had)
    (by simpa [desugarDef, ht, TypeCtx.kinds, Refinement.Def.tel, FunDecl.tel] using hsig)
  have hf' : HasTypeV P B StoreTy.empty [] [] [] (.fnRef "main" [] [] [])
      (.dependentFn (.done d.ret d.eff)) := by
    change HasTypeVQ _ _ _ _ _ _ _ _ (.dependentFn (instantiatedTel d.toFunDecl.tel [] [])) at hf
    rw [hinst, htel] at hf
    exact hf
  exact ⟨d.ret, hret, htel ▸ ha, .C_DependentApp hf' (.done (htel ▸ ha))⟩

/-- 利用者自身の脱糖した宣言表で、main の開始を型付ける。 -/
theorem main_typed {p : Program} {B : Builtins} {op : OpPrim} {ε : Eff}
    (hwf : p.WellFormed) (hmain : p.HasMain ε) :
    ∃ a, MainReturn a ∧ Ty.Annotation (desugarProgram op p) [] [] (.dependentFn (.done a ε)) ∧
      HasTypeC (desugarProgram op p) B StoreTy.empty [] [] [] none
        (.app (.fnRef "main" [] [] []) []) a ε :=
  main_typed_realized hwf hmain (declarationsFor_sameTypes op p closedView) (fun _ _ h => h)

/-- 型付け・閉性・保持値の適格性は main の宣言から得る。起点の束縛は環境から得る。 -/
theorem main_start {p : Program} {B : Builtins} {op : OpPrim} {ε : Eff} {σ : PathEnv}
    (hwf : p.WellFormed) (hmain : p.HasMain ε)
    (hready : σ.Ready (desugarProgram op p) B (.run mainClosure [] Store.empty)) :
    ∃ a, MainReturn a ∧ ClosureTy (desugarProgram op p) B StoreTy.empty [] none mainClosure a ε ∧
      StartCondition (desugarProgram op p) B σ mainClosure := by
  obtain ⟨a, hm, hann, ht⟩ := main_typed (B := B) (op := op) hwf hmain
  have hn : a.Normal := by rcases hm with rfl | rfl <;> rfl
  have hq := ClosureTy.pure ht hann (by intro r h; cases h) hn (by intro r h; cases h)
  exact ⟨a, hm, hq, StartCondition.of_noLamNames ht (by constructor <;> trivial)
    (by simp [Comp.ClosedNoLamNames, Val.ClosedNoLamNames, Val.ClosedNoLamNamesList]) ⟨hready⟩⟩

/-- 空の効果を宣言した main から到達した状態は、事象を出さず未処理の操作を呼ばない。 -/
theorem surface_effect_soundness {p : Program} {B : Builtins} {op : OpPrim} {σ : PathEnv}
    (hwf : p.WellFormed) (hwt : p.WellTyped B op)
    (hc : B.CoreAssumptions (desugarProgram op p)) (hm : p.HasMain Eff.empty)
    (hr : σ.Ready (desugarProgram op p) B (.run mainClosure [] Store.empty)) :
    ∀ evs s, Steps (desugarProgram op p) B σ (.run mainClosure [] Store.empty) evs s →
      (∀ ev s', ¬ Step (desugarProgram op p) B σ s (some ev) s') ∧ ¬ UnhandledOp s := by
  obtain ⟨hf, ht, he⟩ := desugar_typed hwf hwt hc.values
  obtain ⟨a, _, hq, hs⟩ := main_start hwf hm hr
  exact Refinement.effect_soundness _ _ σ hf ht he hc _ a hq hs

/-- main の宣言した同じ効果 ε が、到達先での IO の対象を許す。 -/
theorem surface_target_sound {p : Program} {B : Builtins} {op : OpPrim} {σ : PathEnv} {ε : Eff}
    (hwf : p.WellFormed) (hwt : p.WellTyped B op)
    (hc : B.CoreAssumptions (desugarProgram op p)) (ht : B.TargetAgreement (desugarProgram op p))
    (hm : p.HasMain ε) (hr : σ.Ready (desugarProgram op p) B (.run mainClosure [] Store.empty)) :
    ∀ evs s s' b ws o obs, Steps (desugarProgram op p) B σ (.run mainClosure [] Store.empty) evs s →
      Step (desugarProgram op p) B σ s (some (.io b ws o obs)) s' →
      ∃ e l, B.sig b = some e ∧ e.opEff = some l ∧ ∀ t ∈ obs, Eff.Allows σ B.effKind ε l t := by
  obtain ⟨hf, hp, he⟩ := desugar_typed hwf hwt hc.values
  obtain ⟨a, _, hq, hs⟩ := main_start hwf hm hr
  exact Refinement.reachable_target_sound _ _ σ hf hp he hc ht _ a ε hq hs

end
end Benitoite.Release.Refinement.Surface
