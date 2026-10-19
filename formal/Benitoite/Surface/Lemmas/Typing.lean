import Benitoite.Surface.Lemmas.CallHead
import Benitoite.Surface.Lemmas.Dict
import Benitoite.Surface.Lemmas.Scoped
import Benitoite.Surface.Lemmas.Extensions
import Benitoite.Surface.Lemmas.Records
import Benitoite.Surface.Lemmas.ReturnTry
import Benitoite.Surface.Lemmas.Builders

/-! 全構文の脱糖の型保存と、呼び出し・穴・パイプの組み立て（設計書 01-12「呼び出し」「表層からの脱糖」）。 -/
namespace Benitoite.Surface
open Benitoite.Release

variable {Q : NoFailCtx}

variable {view : CoverageView}

variable {p : Program} {B : Builtins} {op : OpPrim}

theorem HasTypesQ.desugar_of_expr {Δb : BuilderCtx} {C Γ}
    (hAlign : BuilderCtx.Aligned Γ Δb) (hΔ : BuilderCtx.Clean C.length Δb)
    (preserve : ∀ {Δb C Γ R pos e a ε pe},
      BuilderCtx.Aligned Γ Δb → BuilderCtx.Clean C.length Δb →
      HasTypeQ (p.declarationsFor view) B op Q Δb C Γ R pos e a ε →
      e.Scoped C.length pe Γ.length → EnvClean C.length Γ →
      (∀ r, R = some r → TyOK C.length r) →
      HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C (fillBuilders Γ Δb) R (desugarExpr op pos e) a ε)
    (hwf : p.WellFormed)
    (hsig : ∀ b s, B.sig b = some s → s.Scoped) {R es as ε pe}
    (h : HasTypesQ (p.declarationsFor view) B op Q Δb C Γ R es as ε)
    (sc : es.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
    (hR : ∀ r, R = some r → TyOK C.length r) :
    CompTypesQ (desugarProgram op p) B Q C (fillBuilders Γ Δb) R ε (desugarExprs op es) as ∧
      Ty.VarsInList C.length (fun _ => True) as := by
  match h with
  | .nil => exact ⟨.nil, trivial⟩
  | .cons h hs =>
      obtain ⟨hms, hclean⟩ := HasTypesQ.desugar_of_expr hAlign hΔ preserve hwf hsig hs sc.2 hΓ hR
      exact ⟨.cons (HasTypeCQ.weakenEff (preserve hAlign hΔ h sc.1 hΓ hR) (eff_left _ _))
        (hms.weaken (eff_right _ _)), HasTypeQ.clean hΔ hwf hsig h sc.1 hΓ hR, hclean⟩

theorem HasEachQ.desugar_of_expr {Δb : BuilderCtx} {C Γ}
    (hAlign : BuilderCtx.Aligned Γ Δb) (hΔ : BuilderCtx.Clean C.length Δb)
    (preserve : ∀ {Δb C Γ R pos e a ε pe},
      BuilderCtx.Aligned Γ Δb → BuilderCtx.Clean C.length Δb →
      HasTypeQ (p.declarationsFor view) B op Q Δb C Γ R pos e a ε →
      e.Scoped C.length pe Γ.length → EnvClean C.length Γ →
      (∀ r, R = some r → TyOK C.length r) →
      HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C (fillBuilders Γ Δb) R (desugarExpr op pos e) a ε)
    (hwf : p.WellFormed)
    (hsig : ∀ b s, B.sig b = some s → s.Scoped) {R es a ε pe}
    (h : HasEachQ (p.declarationsFor view) B op Q Δb C Γ R es a ε)
    (sc : es.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
    (hR : ∀ r, R = some r → TyOK C.length r) :
    CompTypesQ (desugarProgram op p) B Q C (fillBuilders Γ Δb) R ε (desugarExprs op es) (List.replicate es.length a) := by
  match h with
  | .nil => exact .nil
  | .cons h hs =>
      simp only [Exprs.length, List.replicate_succ]
      exact .cons (HasTypeCQ.weakenEff (preserve hAlign hΔ h sc.1 hΓ hR) (eff_left _ _))
        ((HasEachQ.desugar_of_expr hAlign hΔ preserve hwf hsig hs sc.2 hΓ hR).weaken (eff_right _ _))

/-- prior は左で既に通った穴の型。残りの穴と合わせてラムダの全引数を表す。
右に残る穴の個数が現在の穴の番号となり、非穴の式は全引数の下へ弱化する。 -/
theorem HasHoleArgsQ.desugar_of_expr {Δb : BuilderCtx} {C Γ}
    (hAlign : BuilderCtx.Aligned Γ Δb) (hΔ : BuilderCtx.Clean C.length Δb)
    (preserve : ∀ {Δb C Γ R pos e a ε pe},
      BuilderCtx.Aligned Γ Δb → BuilderCtx.Clean C.length Δb →
      HasTypeQ (p.declarationsFor view) B op Q Δb C Γ R pos e a ε →
      e.Scoped C.length pe Γ.length → EnvClean C.length Γ →
      (∀ r, R = some r → TyOK C.length r) →
      HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C (fillBuilders Γ Δb) R (desugarExpr op pos e) a ε)
    (hwf : p.WellFormed)
    (hsig : ∀ b s, B.sig b = some s → s.Scoped) {R args as ε pe}
    (h : HasHoleArgsQ (p.declarationsFor view) B op Q Δb C Γ R args as ε)
    (sc : args.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
    (hR : ∀ r, R = some r → TyOK C.length r) (prior : List Ty) :
    CompTypesQ (desugarProgram op p) B Q C (binds (prior ++ args.holeTypes) ++ fillBuilders Γ Δb) R ε
      (desugarHoleArgs op (prior ++ args.holeTypes).length args) as ∧
      Ty.VarsInList C.length (fun _ => True) as := by
  match h with
  | .nil => exact ⟨.nil, trivial⟩
  | .expr (args := rest) he hs =>
      obtain ⟨hms, hc⟩ := HasHoleArgsQ.desugar_of_expr hAlign hΔ preserve hwf hsig hs sc.2 hΓ hR prior
      have he' := preserve hAlign hΔ he sc.1 hΓ hR
      have shifted := he'.rename (RenOk.shift (binds (prior ++ rest.holeTypes)) (fillBuilders Γ Δb))
      exact ⟨.cons (HasTypeCQ.weakenEff (by simpa only [binds_length, HoleArgs.holeTypes] using shifted)
        (eff_left _ _)) (hms.weaken (eff_right _ _)), HasTypeQ.clean hΔ hwf hsig he sc.1 hΓ hR, hc⟩
  | .hole (t := t) (args := rest) hl ha hs =>
      obtain ⟨hms, hc⟩ := HasHoleArgsQ.desugar_of_expr hAlign hΔ preserve hwf hsig hs sc.2 hΓ hR (prior ++ [t])
      refine ⟨.cons (HasTypeCQ.weakenEff (.C_Return (.V_Sub (.V_Var ?_
        (clean_notCont (scoped_clean sc.1))) hl (Ty.VarsIn.wf _ ha))) (Eff.empty_sub _))
        (by simpa only [HoleArgs.holeTypes, List.append_assoc, List.singleton_append] using hms),
        ha, hc⟩
      simp only [HoleArgs.holeTypes, binds_append, binds_cons, List.append_assoc, List.singleton_append]
      rw [List.getElem?_append_right (by simp [binds_length])]
      simp [binds_length]


/-- 通常の呼び出しでは、callee の計算を先行させてソース順に引数を束縛する。 -/
theorem HasTypeQ.desugar_call {Δb : BuilderCtx} {C Γ Γc R pos f labels positions args names ps a εf εargs εcall}
    (hΓc : RenOk Γ Γc id)
    (hf : HasTypeQ (p.declarationsFor view) B op Q Δb C Γ R .other f (.fn names ps a εcall) εf)
    (hp : CallOk names ps false labels positions)
    (hf' : HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C Γc R
      (desugarExpr op .other f) (.fn names ps a εcall) εf)
    (hm : CompTypesQ (desugarProgram op p) B Q C Γc R εargs (desugarExprs op args) (sourceTypes ps positions))
    (hc : Ty.VarsInList C.length (fun _ => True) (sourceTypes ps positions)) :
    HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C Γc R
      (desugarExpr op pos (.call f labels positions args)) a (Eff.union εf (Eff.union εargs εcall)) := by
  apply callComp_typed (names := names) (εcall := εcall) [] rfl (by simpa using hp.2.2.1)
    (HasTypeCQ.weakenEff (by simpa only [List.nil_append, List.length_nil] using (hf'.rename (RenOk.shift ([] : List (Option Ty)) Γc))) (eff_left _ _))
    (fun h hd ys => by
      simpa only [List.nil_append, Nat.zero_add, List.append_assoc] using
        ((directCallee_typed hd hf hf' hΓc).rename (RenOk.shift ys Γc)))
    .nil (hm.weaken ((eff_left _ _).trans (eff_right _ _))) hc
    ((eff_right _ _).trans (eff_right _ _))

/-- パイプでは左辺を一度束縛して位置 0 を占め、その後に callee と明示引数を置く。 -/
theorem HasTypeQ.desugar_pipeCall {Δb : BuilderCtx} {C Γ Γc R pos lhs f labels positions args names t ps a εl εf εargs εcall}
    (hΓc : RenOk Γ Γc id)
    (hf : HasTypeQ (p.declarationsFor view) B op Q Δb C Γ R .other f (.fn names (t :: ps) a εcall) εf)
    (hp : CallOk names (t :: ps) true labels positions)
    (hl' : HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C Γc R (desugarExpr op .other lhs) t εl)
    (hf' : HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C Γc R
      (desugarExpr op .other f) (.fn names (t :: ps) a εcall) εf)
    (hm : CompTypesQ (desugarProgram op p) B Q C Γc R εargs (desugarExprs op args) (sourceTypes (t :: ps) positions))
    (hc : Ty.VarsInList C.length (fun _ => True) (sourceTypes (t :: ps) positions))
    (ht : TyOK C.length t) :
    HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C Γc R
      (desugarExpr op pos (.pipe lhs (.call f labels positions args))) a
      (Eff.union εl (Eff.union εf (Eff.union εargs εcall))) := by
  apply typedLet hl'
  apply callComp_typed [some t] rfl (by simpa using hp.2.2.1)
    (HasTypeCQ.weakenEff (HasTypeCQ.shiftOne hf') (eff_left _ _))
    (fun h hd ys => by
      simpa only [List.length_append, List.length_singleton, List.singleton_append, List.append_nil,
        Nat.add_comm, List.append_assoc] using
        ((directCallee_typed hd hf hf' hΓc).rename (RenOk.shift (ys ++ [some t]) Γc)))
    (by simpa [sourceTypes] using (HasTypeVsQ.cons (.V_Var rfl (clean_notCont ht)) HasTypeVsQ.nil))
    (hm.weaken ((eff_left _ _).trans (eff_right _ _))) hc
    ((eff_right _ _).trans (eff_right _ _))

/-- 括弧・穴付きの右辺の関数値への適用は、一引数のままである。 -/
theorem HasTypeQ.desugar_pipeApply {Δb : BuilderCtx} {C Γ Γc R pos lhs rhs name t a εl εf εcall}
    (hp : rhs.PipeValue)
    (hΓc : RenOk Γ Γc id)
    (hf : HasTypeQ (p.declarationsFor view) B op Q Δb C Γ R .other rhs (.fn [name] [t] a εcall) εf)
    (hl' : HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C Γc R (desugarExpr op .other lhs) t εl)
    (hf' : HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C Γc R
      (desugarExpr op .other rhs) (.fn [name] [t] a εcall) εf)
    (ht : TyOK C.length t) :
    HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C Γc R
      (desugarExpr op pos (.pipe lhs rhs)) a (Eff.union εl (Eff.union εf εcall)) := by
  rw [desugarPipeValue hp]
  apply typedLet hl'
  apply callComp_typed (names := [name]) (ps := [t]) (positions := []) [some t] rfl (by simp)
    (HasTypeCQ.weakenEff (HasTypeCQ.shiftOne hf') (eff_left _ _))
    (fun h hd ys => by
      simpa only [List.length_append, List.length_singleton, List.singleton_append, List.append_nil,
        Nat.add_comm, List.append_assoc] using
        ((directCallee_typed hd hf hf' hΓc).rename (RenOk.shift (ys ++ [some t]) Γc)))
    (by simpa [sourceTypes] using (HasTypeVsQ.cons (.V_Var rfl (clean_notCont ht)) HasTypeVsQ.nil))
    (CompTypesQ.nil.weaken (Eff.empty_sub _)) trivial (eff_right _ _)

/-- 穴の契約はソース順に保持し、callee と固定引数の計算はラムダの内側に置く。 -/
theorem HasTypeQ.desugar_partialCall {Δb : BuilderCtx} {C Γ Γc R pos f names args ps r0 r ε εf εargs εcall}
    (hΓc : RenOk Γ Γc id)
    (hf : HasTypeQ (p.declarationsFor view) B op Q Δb C (hideConts Γ) (some r) .other f (.fn names ps r0 εcall) εf)
    (hp : CallOk names ps false args.labels args.positions)
    (hn : NamesWF (args.holeNames names) args.holeTypes)
    (hf' : HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C (hideConts Γc) (some r)
      (desugarExpr op .other f) (.fn names ps r0 εcall) εf)
    (hm : CompTypesQ (desugarProgram op p) B Q C (binds args.holeTypes ++ hideConts Γc) (some r) εargs
      (desugarHoleArgs op args.holeTypes.length args) (sourceTypes ps args.positions))
    (hc : Ty.VarsInList C.length (fun _ => True) (sourceTypes ps args.positions))
    (hl : Ty.Le r0 r) (he : Eff.Sub (Eff.union εf (Eff.union εargs εcall)) ε)
    (resultWF : Ty.WF C.length (.fn (args.holeNames names) args.holeTypes r ε)) :
    HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C Γc R
      (desugarExpr op pos (.partialCall f names args r ε))
      (.fn (args.holeNames names) args.holeTypes r ε) Eff.empty := by
  apply HasTypeCQ.C_Return
  apply HasTypeVQ.V_Lam hn resultWF
  apply HasTypeCQ.C_Sub (a := r0) (ε := Eff.union εf (Eff.union εargs εcall)) _ hl he resultWF.2.2.1
  apply callComp_typed (names := names) (εcall := εcall) [] rfl (by simpa using hp.2.2.1)
    (HasTypeCQ.weakenEff (by simpa only [binds_length, List.nil_append] using
      (hf'.rename (RenOk.shift (binds args.holeTypes) (hideConts Γc)))) (eff_left _ _))
    (fun h hd ys => by
      simpa only [List.length_append, binds_length, Nat.add_comm,
        List.nil_append, List.append_nil, List.append_assoc] using
        ((directCallee_typed hd hf hf' hΓc.hide).rename
          (RenOk.shift (ys ++ binds args.holeTypes) (hideConts Γc))))
    .nil (hm.weaken ((eff_left _ _).trans (eff_right _ _))) hc
    ((eff_right _ _).trans (eff_right _ _))

/-- 構成子の直接構築は位置順の規則を維持する。 -/
theorem HasTypeQ.desugar_conCall {C Γ R pos c cd ts args ε}
    (hd : p.declarations.cons c = some cd) (ht : ts.length = cd.ntys)
    (hm : CompTypesQ (desugarProgram op p) B Q C Γ R ε (desugarExprs op args) (cd.args.map (Ty.subst ts [])))
    (hc : Ty.VarsInList C.length (fun _ => True) (cd.args.map (Ty.subst ts []))) :
    HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C Γ R
      (desugarExpr op pos (.conCall c ts args)) (.data cd.data ts) ε := by
  apply sequence_typed hm hc
  intro vs hv
  exact HasTypeCQ.weakenEff (.C_Return (.V_Con hd ht hv)) (Eff.empty_sub _)

/-- 構成子の穴も、固定式をラムダの外へ移さず argN の契約を保持する。 -/
theorem HasTypeQ.desugar_partialCon {C Γ R pos c cd ts args r εargs}
    (hd : p.declarations.cons c = some cd) (ht : ts.length = cd.ntys)
    (hn : NamesWF (args.holeNames (positionalNames args.positions.length)) args.holeTypes)
    (hm : CompTypesQ (desugarProgram op p) B Q C (binds args.holeTypes ++ hideConts Γ) (some r) εargs
      (desugarHoleArgs op args.holeTypes.length args) (cd.args.map (Ty.subst ts [])))
    (hc : Ty.VarsInList C.length (fun _ => True) (cd.args.map (Ty.subst ts [])))
    (hl : Ty.Le (.data cd.data ts) r)
    (resultWF : Ty.WF C.length (.fn (args.holeNames (positionalNames args.positions.length)) args.holeTypes r (Eff.norm εargs))) :
    HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C Γ R
      (desugarExpr op pos (.partialCon c ts args))
      (.fn (args.holeNames (positionalNames args.positions.length)) args.holeTypes r (Eff.norm εargs)) Eff.empty := by
  apply HasTypeCQ.C_Return
  apply HasTypeVQ.V_Lam hn resultWF
  apply HasTypeCQ.C_Sub (a := .data cd.data ts) (ε := εargs) _ hl (Eff.sub_norm_self _) resultWF.2.2.1
  apply sequence_typed hm hc
  intro vs hv
  exact HasTypeCQ.weakenEff (.C_Return (.V_Con hd ht hv)) (Eff.empty_sub _)

/-- 直接の構成子のパイプは、左辺の値を先頭のフィールドに置く。 -/
theorem HasTypeQ.desugar_pipeConCall {C Γ R pos lhs c cd ts args t ps εl εargs}
    (hd : p.declarations.cons c = some cd) (ht : ts.length = cd.ntys)
    (hp : cd.args.map (Ty.subst ts []) = t :: ps)
    (hl' : HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C Γ R (desugarExpr op .other lhs) t εl)
    (hm : CompTypesQ (desugarProgram op p) B Q C Γ R εargs (desugarExprs op args) ps)
    (hc : Ty.VarsInList C.length (fun _ => True) ps) (htc : TyOK C.length t) :
    HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C Γ R
      (desugarExpr op pos (.pipe lhs (.conCall c ts args))) (.data cd.data ts) (Eff.union εl εargs) := by
  apply typedLet hl'
  apply letChain_typed hm [some t]
  rw [hm.length]
  apply HasTypeCQ.weakenEff (δ := εargs)
  · apply HasTypeCQ.C_Return
    apply HasTypeVQ.V_Con hd ht
    rw [hp]
    refine .cons (.V_Var ?_ (clean_notCont htc)) ?_
    · rw [List.append_assoc, List.getElem?_append_right (by simp [binds_length])]
      simp [binds_length]
    · simpa only [List.append_assoc, List.singleton_append] using
        (boundVars_typed (Γ := some t :: Γ) hc)
  · exact Eff.empty_sub _

/-- 裸の一引数構成子へのパイプには、明示引数の計算を加えない。 -/
theorem HasTypeQ.desugar_pipeConValue {C Γ R pos lhs c cd ts names ps t εl}
    (hd : p.declarations.cons c = some cd) (ht : ts.length = cd.ntys)
    (hp : ps = cd.args.map (Ty.subst ts [])) (hps : ps = [t])
    (hl' : HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C Γ R (desugarExpr op .other lhs) t εl)
    (htc : TyOK C.length t) :
    HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C Γ R
      (desugarExpr op pos (.pipe lhs (.conValue c ts names ps))) (.data cd.data ts) εl := by
  apply HasTypeCQ.C_Let hl'
  apply HasTypeCQ.weakenEff (δ := εl)
  · apply HasTypeCQ.C_Return
    apply HasTypeVQ.V_Con hd ht
    rw [← hp, hps]
    exact .cons (.V_Var rfl (clean_notCont htc)) .nil
  · exact Eff.empty_sub _

namespace CallExamples

private def reversedArgs : Exprs :=
  .cons (.literal (.boolean true)) (.cons (.literal (.integer 7)) .nil)

/-- 異なる型の逆順指定を一般の呼び出しの保存から導く。 -/
example (p : Program) (B : Builtins) (op : OpPrim) :
    HasTypeCQ (desugarProgram op p) B StoreTy.empty Q []
      [some (.fn ["a", "b"] [.base .integer, .base .boolean] (.base .integer) Eff.empty)] none
      (desugarExpr op .other (.call (.local 0) [some "b", some "a"] [1, 0] reversedArgs))
      (.base .integer) Eff.empty := by
  have hf : HasTypeQ (p.declarationsFor view) B op Q [] []
      [some (.fn ["a", "b"] [.base .integer, .base .boolean] (.base .integer) Eff.empty)] none .other
      (.local 0) (.fn ["a", "b"] [.base .integer, .base .boolean] (.base .integer) Eff.empty) Eff.empty :=
    .E_Local rfl (by intro _ _ _ h; cases h)
  have hp : CallOk ["a", "b"] [.base .integer, .base .boolean] false [some "b", some "a"] [1, 0] := by
    refine ⟨by simp [NamesWF], rfl, ?_, Or.inr (Or.inr ⟨rfl, ?_⟩)⟩
    · exact List.Perm.swap _ _ []
    · intro label h; simp at h; rcases h with rfl | rfl <;> rfl
  have hm : CompTypesQ (desugarProgram op p) B Q []
      [some (.fn ["a", "b"] [.base .integer, .base .boolean] (.base .integer) Eff.empty)] none Eff.empty
      (desugarExprs op reversedArgs) (sourceTypes [.base .integer, .base .boolean] [1, 0]) :=
    .cons (.C_Return .V_Const) (.cons (.C_Return .V_Const) .nil)
  simpa only [union_empty_left Eff.empty rfl] using HasTypeQ.desugar_call (pos := .other) (fun _ _ hi => hi) hf hp
    (.C_Return (.V_Var rfl (by intro _ _ _ h; cases h))) hm (by trivial)

private def mixedHoles : HoleArgs :=
  .hole (some "b") 1 (.base .boolean)
    (.expr (some "c") 2 (.call (.opName "fixed" []) [] [] .nil) (.hole (some "a") 0 (.base .integer) .nil))

private def fixedOp : OpDecl :=
  { tparams := [], names := [], params := [], ret := .base .integer, eff := "Fixed" }

/-- 穴 b, a の契約と、エフェクトを持つ固定式をラムダ内で評価する型保存を導く。 -/
example (p : Program) (B : Builtins) (op : OpPrim)
    (hd : p.ops "fixed" = some fixedOp) :
    HasTypeCQ (desugarProgram op p) B StoreTy.empty Q []
      [some (.fn ["a", "b", "c"] [.base .integer, .base .boolean, .base .integer] (.base .integer) Eff.empty)] none
      (desugarExpr op .other (.partialCall (.local 0) ["a", "b", "c"] mixedHoles (.base .integer) (Eff.single "Fixed")))
      (.fn ["b", "a"] [.base .boolean, .base .integer] (.base .integer) (Eff.single "Fixed")) Eff.empty := by
  have hf : HasTypeQ (p.declarationsFor view) B op Q [] []
      [some (.fn ["a", "b", "c"] [.base .integer, .base .boolean, .base .integer] (.base .integer) Eff.empty)]
      (some (.base .integer)) .other (.local 0)
      (.fn ["a", "b", "c"] [.base .integer, .base .boolean, .base .integer] (.base .integer) Eff.empty) Eff.empty :=
    .E_Local rfl (by intro _ _ _ h; cases h)
  have hp : CallOk ["a", "b", "c"] [.base .integer, .base .boolean, .base .integer] false
      mixedHoles.labels mixedHoles.positions := by
    refine ⟨by simp [NamesWF], rfl, ?_, Or.inr (Or.inr ⟨rfl, ?_⟩)⟩
    · exact (List.Perm.cons _ (List.Perm.swap _ _ [])).trans (List.Perm.swap _ _ [_])
    · intro label h
      simp [mixedHoles, HoleArgs.labels] at h
      rcases h with rfl | rfl | rfl <;> rfl
  have hm : CompTypesQ (desugarProgram op p) B Q []
      (binds mixedHoles.holeTypes ++ hideConts
        [some (.fn ["a", "b", "c"] [.base .integer, .base .boolean, .base .integer] (.base .integer) Eff.empty)])
      (some (.base .integer)) (Eff.single "Fixed") (desugarHoleArgs op mixedHoles.holeTypes.length mixedHoles)
      (sourceTypes [.base .integer, .base .boolean, .base .integer] mixedHoles.positions) := by
    have hfixed : HasTypeCQ (desugarProgram op p) B StoreTy.empty Q []
        (binds mixedHoles.holeTypes ++ hideConts
          [some (.fn ["a", "b", "c"] [.base .integer, .base .boolean, .base .integer] (.base .integer) Eff.empty)])
        (some (.base .integer)) (desugarExpr op .other (.call (.opName "fixed" []) [] [] .nil))
        (.base .integer) (Eff.single "Fixed") := by
      have heff : Eff.substAt 0 [] [] (Eff.single "Fixed") = Eff.single "Fixed" :=
        Eff.substAt_ofAtoms 0 [] _
      have hv : HasTypeVQ (desugarProgram op p) B StoreTy.empty Q []
          (binds mixedHoles.holeTypes ++ hideConts
            [some (.fn ["a", "b", "c"] [.base .integer, .base .boolean, .base .integer] (.base .integer) Eff.empty)])
          (.op "fixed" []) (.fn [] [] (.base .integer) (Eff.single "Fixed")) := by
        simpa only [fnTy_eq, fixedOp, Ty.subst, Ty.substAt, heff, List.map_nil] using
          (HasTypeVQ.V_Op (P := desugarProgram op p) (B := B) (Ψ := StoreTy.empty)
            (C := []) (Γ := binds mixedHoles.holeTypes ++ hideConts
              [some (.fn ["a", "b", "c"] [.base .integer, .base .boolean, .base .integer] (.base .integer) Eff.empty)])
            (ts := []) hd (by simp [fixedOp, NamesWF]) (by simp [SatAll, fixedOp]))
      simpa [desugarExpr, callComp, directCallee, letChain, desugarExprs, recordFields,
        Val.rename, Val.renameList, boundVars, CallHead.rename, CallHead.apply] using
        (HasTypeCQ.C_App (R := some (.base .integer)) hv HasTypeVsQ.nil)

    exact .cons (HasTypeCQ.weakenEff (.C_Return (.V_Var rfl (by intro _ _ _ h; cases h))) (Eff.empty_sub _))
      (.cons hfixed (.cons (HasTypeCQ.weakenEff (.C_Return (.V_Var rfl (by intro _ _ _ h; cases h)))
        (Eff.empty_sub _)) .nil))

  exact HasTypeQ.desugar_partialCall (fun _ _ hi => hi) hf hp
    (by simp [mixedHoles, HoleArgs.holeNames, HoleArgs.holeTypes, NamesWF])
    (.C_Return (.V_Var rfl (by intro _ _ _ h; cases h))) hm (by trivial) (.refl _) (by
      constructor
      · intro a ha; simpa only [Eff.mem_union, Eff.mem_empty, false_or, or_false] using ha
      · intro t ht; simpa only [Eff.memFail_union, Eff.memFail_empty, false_or, or_false] using ht)
    (by simp [mixedHoles, HoleArgs.holeNames, HoleArgs.holeTypes, Ty.WF, Ty.WFList, NamesWF, Eff.WF, Eff.Canonical, Eff.single, Eff.ofAtoms, Eff.norm, Ty.normTys])

private def pipeArgs : Exprs :=
  .cons (.literal (.integer 7)) (.cons (.literal (.boolean true)) .nil)

/-- パイプの位置 0 と、逆順に明示した残りの二引数を同じ保存の定理から導く。 -/
example (p : Program) (B : Builtins) (op : OpPrim) :
    HasTypeCQ (desugarProgram op p) B StoreTy.empty Q []
      [some (.fn ["a", "b", "c"] [.base .integer, .base .boolean, .base .integer] (.base .integer) Eff.empty)] none
      (desugarExpr op .other (.pipe (.literal (.integer 5))
        (.call (.local 0) [some "c", some "b"] [2, 1] pipeArgs))) (.base .integer) Eff.empty := by
  have hf : HasTypeQ (p.declarationsFor view) B op Q [] []
      [some (.fn ["a", "b", "c"] [.base .integer, .base .boolean, .base .integer] (.base .integer) Eff.empty)] none .other
      (.local 0) (.fn ["a", "b", "c"] [.base .integer, .base .boolean, .base .integer] (.base .integer) Eff.empty) Eff.empty :=
    .E_Local rfl (by intro _ _ _ h; cases h)
  have hp : CallOk ["a", "b", "c"] [.base .integer, .base .boolean, .base .integer] true
      [some "c", some "b"] [2, 1] := by
    refine ⟨by simp [NamesWF], rfl, ?_, Or.inr (Or.inr ⟨rfl, ?_⟩)⟩
    · exact List.Perm.cons _ (List.Perm.swap _ _ [])
    · intro label h; simp at h; rcases h with rfl | rfl <;> rfl
  have hm : CompTypesQ (desugarProgram op p) B Q []
      [some (.fn ["a", "b", "c"] [.base .integer, .base .boolean, .base .integer] (.base .integer) Eff.empty)] none Eff.empty
      (desugarExprs op pipeArgs) (sourceTypes [.base .integer, .base .boolean, .base .integer] [2, 1]) :=
    .cons (.C_Return .V_Const) (.cons (.C_Return .V_Const) .nil)
  simpa only [union_empty_left Eff.empty rfl] using HasTypeQ.desugar_pipeCall (pos := .other) (lhs := .literal (.integer 5)) (fun _ _ hi => hi) hf hp
    (.C_Return .V_Const) (.C_Return (.V_Var rfl (by intro _ _ _ h; cases h))) hm (by trivial) (by trivial)

end CallExamples

/-!
同じ Δ の子の帰納自体をセル環境で得る。空 Δ の境界だけは、子の導出を既存の
恒等の番号対応で移す（設計書 01-12「構築器の局所文脈と旧構文の意味」）。
-/
-- 宣言を含む七判断の相互帰納の elaboration に余裕を持たせる。
set_option maxHeartbeats 800000 in
mutual
  theorem HasTypeQ.desugar {Δb : BuilderCtx} {C Γ}
      (hAlign : BuilderCtx.Aligned Γ Δb) (hΔ : BuilderCtx.Clean C.length Δb) (hwf : p.WellFormed)
      (hsig : ∀ b s, B.sig b = some s → s.Scoped) {R pos e a ε pe}
      (h : HasTypeQ (p.declarationsFor view) B op Q Δb C Γ R pos e a ε)
      (sc : e.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
      (hR : ∀ r, R = some r → TyOK C.length r) :
      HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C (fillBuilders Γ Δb) R (desugarExpr op pos e) a ε := by
    have resultWF := Ty.VarsIn.wf _ (HasTypeQ.clean hΔ hwf hsig h sc hΓ hR)
    match h with
    | .E_BuilderOp hr ha =>
        obtain ⟨hm, hclean⟩ := HasTypesQ.desugar hAlign hΔ hwf hsig ha sc.2.2 hΓ hR
        exact builderOp_desugar_typed hAlign hr hm hclean
    | .E_Local hi hc => exact .C_Return (.V_Var (fillBuilders.value_lookup hAlign hi) hc)
    | .E_Const h =>
        have hb := HasTypeQ.desugar (BuilderCtx.aligned_empty _) (BuilderCtx.clean_empty _) hwf hsig h sc.2 (by intro i a hi; simp at hi) hR
        -- 空の環境からは、id の付け替えで任意の使用位置の環境へ移せる。
        simp only [fillBuilders.empty] at hb
        have shifted := hb.rename (Δ := fillBuilders Γ Δb) (ξ := id) (by intro i a hi; simp at hi)
        simpa only [desugarExpr, Comp.rename_id] using shifted
    | .E_Fun hd hn hcore ht he hdict hrows _ =>
        obtain ⟨dd, hd', ht', he', hn', hp', hr', hε'⟩ := funDecl_desugared (op := op) hd
        rw [desugarExpr]
        rw [← ht'] at ht; rw [← he'] at he
        simpa only [hn', FunDecl.coreNames, internalNames, List.length_nil, List.range_zero,
          hp', FunDecl.dictTys, hdict, List.map_nil, List.nil_append, hr', hε'] using
          HasTypeCQ.C_Return (R := R)
            (HasTypeVQ.V_Fun hd' (by simpa only [hn', hp'] using hcore)
              (by simpa only [ht', he', hp', hr', hε'] using hrows))
    | .E_FunDicts (d := d) (ps := ps) (ts := ts) (es := es) hd hn hcore ht he _ hnames hp hds hrows _ =>
        obtain ⟨dd, hd', ht', he', hn', hp', hr', hε'⟩ := funDecl_desugared (op := op) hd
        have hv := (DictEv.HasTypes.toVal (Q := Q) op (DictEv.HasTypes.hide hds)).rename
          (fillBuilders.renOk hAlign).hide
        simp only [Val.renameList_id] at hv
        have hs := hv.rename (RenOk.shift (binds ps) (hideConts (fillBuilders Γ Δb)))
        rw [d.dictTys_substEff ts es] at hs
        rw [desugarExpr, fnTy_eq, ← hp, hnames]
        apply HasTypeCQ.C_Return
        apply HasTypeVQ.V_Lam (by simpa only [NamesWF, hp, List.length_map] using hn) (by simpa only [fnTy_eq, ← hp, hnames] using resultWF)
        apply HasTypeCQ.C_App
        · rw [← ht'] at ht; rw [← he'] at he
          simpa only [fnTy_eq, hn', FunDecl.coreNames, hp', List.map_append, hr', hε', hp] using
            (HasTypeVQ.V_Fun (Γ := binds ps ++ hideConts (fillBuilders Γ Δb)) hd' (by simpa only [hn', hp'] using hcore)
              (by simpa only [ht', he', hp', hr', hε'] using hrows))
        · simpa only [binds_length, hp] using
            hs.append (boundVars_typed (scopedList_clean sc.2.2.2.2))
    | .E_MethName (ps := ps) hd hc hm hn hnames ht he hu hp _ hscope hrows _ =>
        have hdict := (DictEv.HasType.toVal (Q := Q) op (DictEv.HasType.hide hd)).rename
          (fillBuilders.renOk hAlign).hide
        have hdicts := (DictEv.HasTypes.toVal (Q := Q) op (DictEv.HasTypes.hide hu)).rename
          (fillBuilders.renOk hAlign).hide
        simp only [Val.rename_id] at hdict
        simp only [Val.renameList_id] at hdicts
        have hv := HasTypeVQ.shiftMany hdict ps
        have hus := hdicts.rename (RenOk.shift (binds ps) (hideConts (fillBuilders Γ Δb)))
        rw [desugarExpr]
        apply HasTypeCQ.C_Return
        apply HasTypeVQ.V_Lam sc.2.2.2.2.1 resultWF
        apply HasTypeCQ.C_Meth hv (classDecl_desugared hc) hm hn ht hscope hrows
        have hargs := hus.append (boundVars_typed (scopedList_clean sc.2.2.2.2.2))
        simpa only [binds_length, hp, List.take_append_drop] using hargs
    | .E_Prim hs hn ht he ha hrows _ => exact .C_Return (.V_Prim hs hn hrows)
    | .E_Op hd hn ht _ => exact .C_Return (.V_Op hd hn ht)
    | .E_OpDicts (od := od) (ps := ps) (ts := ts) hd hcore hn ht hpref hnames hns hp hds =>
        have he : Eff.substAt 0 ts [] (Eff.single od.eff) = Eff.single od.eff :=
          Eff.substAt_ofAtoms 0 [] _
        rw [desugarExpr, fnTy_eq, ← hp, hns, he]
        apply HasTypeCQ.C_Return
        exact op_value_typed (op := op) (Q := Q) hd hcore (by simpa only [NamesWF, hp, List.length_map] using hn)
          ht hpref hnames hp hds (fillBuilders.renOk hAlign) (scopedList_clean sc.2.2.2)
          (by simpa only [fnTy_eq, ← hp, hns, he] using resultWF)
    | .E_NullCon hc ht he =>
        apply HasTypeCQ.C_Return
        apply HasTypeVQ.V_Con hc ht
        simpa [he] using (HasTypeVsQ.nil : HasTypeVsQ (desugarProgram op p) B StoreTy.empty Q C (fillBuilders Γ Δb) [] [])
    | .E_ConValue hc ht _ hn hp _ =>
        apply HasTypeCQ.C_Return
        apply HasTypeVQ.V_Lam hn resultWF
        apply HasTypeCQ.C_Return
        apply HasTypeVQ.V_Con hc ht
        rw [← hp]
        exact boundVars_typed (scopedList_clean sc.2.2)
    | .E_PipeCall hl hf hp hs _ =>
        obtain ⟨hm, hc⟩ := HasTypesQ.desugar hAlign hΔ hwf hsig hs sc.2.2 hΓ hR
        exact HasTypeQ.desugar_pipeCall (fillBuilders.renOk hAlign) hf hp
          (HasTypeQ.desugar hAlign hΔ hwf hsig hl sc.1 hΓ hR)
          (HasTypeQ.desugar hAlign hΔ hwf hsig hf sc.2.1 hΓ hR) hm hc
          (HasTypeQ.clean hΔ hwf hsig hl sc.1 hΓ hR)
    | .E_PipeConCall hc ht hp hl hs =>
        obtain ⟨hm, hclean⟩ := HasTypesQ.desugar hAlign hΔ hwf hsig hs sc.2.2 hΓ hR
        exact HasTypeQ.desugar_pipeConCall hc ht hp
          (HasTypeQ.desugar hAlign hΔ hwf hsig hl sc.1 hΓ hR) hm hclean
          (HasTypeQ.clean hΔ hwf hsig hl sc.1 hΓ hR)
    | .E_PipeConValue hc ht _ _ hp hps hl =>
        exact HasTypeQ.desugar_pipeConValue hc ht hp hps
          (HasTypeQ.desugar hAlign hΔ hwf hsig hl sc.1 hΓ hR)
          (HasTypeQ.clean hΔ hwf hsig hl sc.1 hΓ hR)
    | .E_PipeApply hp hl hf _ =>
        exact HasTypeQ.desugar_pipeApply hp (fillBuilders.renOk hAlign) hf
          (HasTypeQ.desugar hAlign hΔ hwf hsig hl sc.1 hΓ hR)
          (HasTypeQ.desugar hAlign hΔ hwf hsig hf sc.2 hΓ hR)
          (HasTypeQ.clean hΔ hwf hsig hl sc.1 hΓ hR)
    | .E_PartialCall _ hf hp hn hs hl he _ =>
        have hr := scoped_clean sc.2.2.1
        have hf' := HasTypeQ.desugar (BuilderCtx.aligned_empty _) (BuilderCtx.clean_empty _) hwf hsig hf
          (by simpa only [hideConts_length] using sc.1) hΓ.hide (by intro r heq; cases heq; exact hr)
        obtain ⟨hm, hc⟩ := HasHoleArgsQ.desugar (BuilderCtx.aligned_empty _) (BuilderCtx.clean_empty _) hwf hsig hs
          (by simpa only [hideConts_length] using sc.2.1) hΓ.hide
          (by intro r heq; cases heq; exact hr) []
        simp only [fillBuilders.empty] at hf' hm
        have hfFilled := HasTypeCQ.renameId (fillBuilders.renOk hAlign).hide hf'
        have hmFilled := hm.renameId (RenOk.up_id (binds _) (fillBuilders.renOk hAlign).hide)
        exact HasTypeQ.desugar_partialCall (fillBuilders.renOk hAlign) hf hp hn hfFilled hmFilled hc hl he resultWF
    | .E_PartialCon _ hd ht _ _ hn hs hl _ =>
        have hr := clean_data_le hl (scopedList_clean sc.1)
        obtain ⟨hm, hc⟩ := HasHoleArgsQ.desugar (BuilderCtx.aligned_empty _) (BuilderCtx.clean_empty _) hwf hsig hs
          (by simpa only [hideConts_length] using sc.2) hΓ.hide
          (by intro r heq; cases heq; exact hr) []
        simp only [fillBuilders.empty] at hm
        exact HasTypeQ.desugar_partialCon hd ht hn
          (hm.renameId (RenOk.up_id (binds _) (fillBuilders.renOk hAlign).hide)) hc hl resultWF
    | .E_Match _ he hs hex =>
        have he' := HasTypeQ.desugar hAlign hΔ hwf hsig he sc.2.1 hΓ hR
        have ha := HasTypeQ.clean hΔ hwf hsig he sc.2.1 hΓ hR
        apply typedLet he'
        apply HasTypeCQ.C_Match (.V_Var rfl (clean_notCont ha))
          (HasArmsQ.desugar hAlign hΔ hwf hsig hs sc.2.2 hΓ hR ha)
        rw [desugarArms_patterns]
        exact Exhaustive.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hex.exhaustive
    | .E_Literal => exact .C_Return .V_Const
    | .E_NegInt => exact .C_Return .V_Const
    | .E_NegFloat => exact .C_Return .V_Const
    | .E_NegDecimal => exact .C_Return .V_Const
    | .E_NegInteger8 => exact .C_Return .V_Const
    | .E_NegInteger16 => exact .C_Return .V_Const
    | .E_NegInteger32 => exact .C_Return .V_Const
    | .E_NegFloat32 => exact .C_Return .V_Const
    | .E_Raise ht he => exact .C_Return (.V_Raise ht he)
    | .E_HandleFail hb he hn hw ht hc hh =>
        apply HasTypeCQ.C_Handle_Fail (HasBlockQ.desugar hAlign hΔ hwf hsig hb sc.2.2.1 hΓ hR) he hn
        apply HasFailureClause.one hw ht hc
        apply HasTypeCQ.renameId (RenOk.up_id [none, some (_ : Ty)]
          ((fillBuilders.renOk hAlign).shiftE 1))
        simpa only [fillBuilders.empty, List.cons_append, List.nil_append] using HasBlockQ.desugar
          (BuilderCtx.aligned_empty _) (BuilderCtx.clean_empty _) hwf hsig hh (by simpa [shiftEnv_length, Nat.add_comm, Nat.add_left_comm, Nat.add_assoc] using sc.2.2.2) (by
          have hg := (hΓ.shift 1).cons (shift_clean 1 _ (scoped_clean sc.1))
          intro i a hi
          cases i with
          | zero => cases hi
          | succ i => exact hg i a hi) (by
          intro r hr
          obtain ⟨a, ha, rfl⟩ := Option.map_eq_some_iff.mp hr
          exact shift_clean 1 a (hR a ha))
    | .E_Unit => exact .C_Return .V_Const
    | .E_Paren h => simpa only [desugarExpr] using HasTypeQ.desugar hAlign hΔ hwf hsig h sc hΓ hR
    | .E_Record hc ht hp hs =>
        obtain ⟨hm, hclean⟩ := HasTypesQ.desugar hAlign hΔ hwf hsig hs sc.2 hΓ hR
        apply sequence_typed hm hclean
        intro vs hv
        apply HasTypeCQ.weakenEff (ε := Eff.empty) _ (Eff.empty_sub _)
        exact .C_Return (.V_Con hc ht (recordFields_typed
          (by simpa only [List.length_map] using hp) hv))
    | .E_RecordUpdate (c := c) (cd := cd) (ts := ts) (n := n) (positions := positions)
        (args := args) hc ht hn _ _ _ hb hs hex =>
        have htypes := substList_clean [] (scopedList_clean sc.1) (by simp) cd.args (by
          rw [ht]; exact scopedList_clean (hwf.2.2.1 _ _ hc))
        let tys := cd.args.map (Ty.subst ts [])
        let t : Nat → Ty := fun i => (tys[i]?).getD (.base .unit)
        let δ := retainedTypes (List.range n) positions t
        have hp : PatTy (desugarProgram op p) (recordUpdatePattern c n positions)
            (.data cd.data ts) δ := by
          apply PatTy.P_Con hc ht
          have h := updateArgs_typed (desugarProgram op p) (List.range n) positions t
          have hr : (List.range n).map t = tys := by
            have hn' : n = tys.length := by simpa only [tys, List.length_map] using hn
            dsimp only [t]
            rw [hn', map_range_getD]
          rw [hr] at h
          exact h
        obtain ⟨hm, hclean⟩ := HasTypesQ.desugar hAlign hΔ hwf hsig hs sc.2.2 hΓ hR
        have hl : args.length = (positions.map t).length := by
          have h := hm.length
          simpa only [desugarExprs_length] using h
        apply typedLet (HasTypeQ.desugar hAlign hΔ hwf hsig hb sc.2.1 hΓ hR)
        apply letChain_typed hm [some (.data cd.data ts)]
        have hvScr : HasTypeVQ (desugarProgram op p) B StoreTy.empty Q C
            (binds (positions.map t) ++ [some (.data cd.data ts)] ++ fillBuilders Γ Δb)
            (.var args.length) (.data cd.data ts) := by
          apply HasTypeVQ.V_Var _ (by intro _ _ _ he; cases he)
          rw [hl, List.append_assoc, List.getElem?_append_right (by simp [binds_length])]
          simp [binds_length]
        apply HasTypeCQ.C_Match hvScr
        · apply HasTypeArmsQ.mkArm_cons hp
          · apply HasTypeCQ.weakenEff (ε := Eff.empty) _ (Eff.empty_sub _)
            apply HasTypeCQ.C_Return
            apply HasTypeVQ.V_Con hc ht
            have hv := boundVars_typed (Q := Q) (P := desugarProgram op p) (B := B)
              (Γ := [some (.data cd.data ts)] ++ fillBuilders Γ Δb) hclean
            change HasTypeVsQ (desugarProgram op p) B StoreTy.empty Q C
              (binds (positions.map t) ++ ([some (.data cd.data ts)] ++ fillBuilders Γ Δb))
              (boundVars (positions.map t).length) (positions.map t) at hv
            rw [← hl, ← List.append_assoc] at hv
            exact recordUpdateValues_typed (by simp only [tys, List.length_map]; exact hn)
              hv htypes hp
          · exact .nil (Ty.VarsIn.wf _ (scopedList_clean sc.1))
        · simpa only [unguardedPats_mkArm_cons, unguardedPats] using
            Exhaustive.consCongr (Q := desugarProgram op p)
            (P := p.declarations.patternProgram) rfl hex
    | .E_ConCall hc ht hs =>
        obtain ⟨hm, hclean⟩ := HasTypesQ.desugar hAlign hΔ hwf hsig hs sc.2 hΓ hR
        exact HasTypeQ.desugar_conCall hc ht hm hclean
    | .E_Call hf hp hs _ =>
        obtain ⟨hm, hc⟩ := HasTypesQ.desugar hAlign hΔ hwf hsig hs sc.2 hΓ hR
        exact HasTypeQ.desugar_call (fillBuilders.renOk hAlign) hf hp (HasTypeQ.desugar hAlign hΔ hwf hsig hf sc.1 hΓ hR) hm hc
    | .E_Binary (o := o) (t := t) (ts := ts) (s := sg) _ hop hts hs hn ht he ha hfn hl hr =>
        have hl' := HasTypeQ.desugar hAlign hΔ hwf hsig hl sc.2.1 hΓ hR
        have hr' := HasTypeQ.desugar hAlign hΔ hwf hsig hr sc.2.2 hΓ hR
        simp only [desugarExpr, hop]
        have hc : Ty.VarsInList C.length (fun _ => True) [t,t] :=
          ⟨scoped_clean sc.1, scoped_clean sc.1, trivial⟩
        apply sequence_typed (.cons (HasTypeCQ.weakenEff hl' (eff_left _ _))
          (.cons (HasTypeCQ.weakenEff hr' (eff_right _ _)) .nil)) hc
        intro vs hv
        apply HasTypeCQ.weakenEff (δ := Eff.union _ _)
        · apply HasTypeCQ.C_App (names := ["left", "right"])
          · rw [← hfn]
            apply HasTypeVQ.V_Prim hs hn
            apply PrimitiveAdmissible.of_noRows (hsig _ _ hs) he ht ha
            intro a ha
            have hc := varsInList_mem (operator_typeArgs_scoped sc.1 (.binary o)) (by simpa only [hts] using ha)
            exact ⟨Ty.VarsIn.wf _ hc, clean_notCont (scoped_clean hc)⟩
          · exact hv
        · exact Eff.empty_sub _
    | .E_Neg _ hop hts hs ht he ha hfn h =>
        have hh := HasTypeQ.desugar hAlign hΔ hwf hsig h sc.2 hΓ hR
        simp only [desugarExpr, hop]
        apply HasTypeCQ.C_Let hh
        apply HasTypeCQ.weakenEff (δ := ε)
        · apply HasTypeCQ.C_App (names := ["value"])
          · rw [← hfn]
            apply HasTypeVQ.V_Prim hs (hsig _ _ hs).1
            apply PrimitiveAdmissible.of_noRows (hsig _ _ hs) he ht ha
            intro a ha
            have hc := varsInList_mem (operator_typeArgs_scoped sc.1 .neg) (by simpa only [hts, Operator.typeArgs] using ha)
            exact ⟨Ty.VarsIn.wf _ hc, clean_notCont (scoped_clean hc)⟩
          · exact .cons (.V_Var rfl (clean_notCont (scoped_clean sc.1))) .nil
        · exact Eff.empty_sub _
    | .E_Not h =>
        apply HasTypeCQ.C_Let (HasTypeQ.desugar hAlign hΔ hwf hsig h sc hΓ hR)
        apply HasTypeCQ.weakenEff (δ := ε)
        · exact .C_If (.V_Var rfl (by intro _ _ _ h; cases h)) (.C_Return .V_Const) (.C_Return .V_Const)
        · exact Eff.empty_sub _
    | .E_And hl hr =>
        have hh := typedIfLet (HasTypeQ.desugar hAlign hΔ hwf hsig hl sc.1 hΓ hR)
          (HasTypeQ.desugar hAlign hΔ hwf hsig hr sc.2 hΓ hR)
          (HasTypeCQ.C_Return (P := desugarProgram op p) (B := B) (Ψ := StoreTy.empty) (C := C) (Γ := fillBuilders Γ Δb) (R := R)
            (HasTypeVQ.V_Const (c := .boolean false)))
        simpa only [desugarExpr, union_empty_right_nested, Comp.rename, Val.rename, Const.type] using hh
    | .E_Or hl hr =>
        have hh := typedIfLet (HasTypeQ.desugar hAlign hΔ hwf hsig hl sc.1 hΓ hR)
          (HasTypeCQ.C_Return (P := desugarProgram op p) (B := B) (Ψ := StoreTy.empty) (C := C) (Γ := fillBuilders Γ Δb) (R := R)
            (HasTypeVQ.V_Const (c := .boolean true)))
          (HasTypeQ.desugar hAlign hΔ hwf hsig hr sc.2 hΓ hR)
        simpa only [desugarExpr, union_empty_left_nested, Comp.rename, Val.rename, Const.type] using hh
    | .E_List (a := t) hw hs =>
        have hclean := scoped_clean sc.1
        have hms := HasEachQ.desugar hAlign hΔ hwf hsig hs sc.2 hΓ hR
        apply sequence_typed hms ?_
        · intro vs hv
          apply HasTypeCQ.weakenEff (.C_Return (.V_List (HasTypeVsQ.each hv ?_) hw)) (Eff.empty_sub _)
          intro t ht; exact List.eq_of_mem_replicate ht
        · exact Ty.VarsInList.mono (Nat.le_refl _) (fun _ h => h) _ (by
            induction Exprs.length _ with
            | zero => trivial
            | succ n ih => exact ⟨hclean, ih⟩)
    | .E_ListSpread (a := t) hw hd hf hb hs ha =>
        have hf' := HasTypeQ.desugar hAlign hΔ hwf hsig hf sc.2.1 hΓ hR
        have hb' := HasEachQ.desugar hAlign hΔ hwf hsig hb sc.2.2.1 hΓ hR
        have hs' := HasTypeQ.desugar hAlign hΔ hwf hsig hs sc.2.2.2.1 hΓ hR
        have ha' := HasEachQ.desugar hAlign hΔ hwf hsig ha sc.2.2.2.2 hΓ hR
        have hc := scoped_clean sc.1
        have hms := (hb'.weaken (eff_left _ _)).append
          (.cons (HasTypeCQ.weakenEff hs' ((eff_left _ _).trans (eff_right _ _)))
            (ha'.weaken ((eff_right _ _).trans (eff_right _ _))))
        simp only [desugarExpr]
        apply sequence_typed hms
          (cleanList_append (replicate_clean hc _) ⟨hc, replicate_clean hc _⟩)
        intro vs hv
        simp only [hd]
        apply HasTypeCQ.weakenEff _ (Eff.empty_sub _)
        apply spreadValues_typed _ hv hw
        simpa only [binds_length, hms.length] using
          (directCallee_typed hd hf hf' (fillBuilders.renOk hAlign)).rename (RenOk.shift (binds _) (fillBuilders Γ Δb))
    | .E_Interpolation _ he hf hd hop =>
        obtain ⟨hms, hc⟩ := HasTypesQ.desugar hAlign hΔ hwf hsig he sc.2.1 hΓ hR
        obtain ⟨hfs, _⟩ := HasTypesQ.desugar hAlign hΔ hwf hsig hf sc.2.2 hΓ hR
        have hh := directHeads_typed (fillBuilders.renOk hAlign) hf hfs hd (converterTypes_fn _)
        simp only [desugarExpr]
        apply sequence_typed hms hc
        intro vs hv
        apply HasTypeCQ.weakenEff (δ := ε) _ (Eff.empty_sub _)
        apply interpolate_typed hsig hv
          (by simpa only [binds_length, hms.length] using hh.rename (RenOk.shift (binds _) (fillBuilders Γ Δb)))
          .nil
        simpa using hop
    | .E_Lam (ps := ps) hn hex hb =>
        apply HasTypeCQ.C_Return
        apply HasTypeVQ.V_Lam hn resultWF
        apply HasTypeCQ.renameId (RenOk.up_id (binds ps) (fillBuilders.renOk hAlign).hide)
        simpa only [fillBuilders.empty, List.cons_append, List.nil_append] using HasBlockQ.desugar
          (BuilderCtx.aligned_empty _) (BuilderCtx.clean_empty _) hwf hsig hb
          (by simpa [binds_length, hideConts_length] using sc.2.2.2.2.2)
          (hΓ.hide.binds (scopedList_clean sc.2.1)) (by intro r he; cases he; exact scoped_clean sc.2.2.1)
    | .E_If hc hy hn _ =>
        exact typedIfLet
          (HasTypeQ.desugar hAlign hΔ hwf hsig hc sc.1 hΓ hR)
          (HasBlockQ.desugar hAlign hΔ hwf hsig hy sc.2.1 hΓ hR)
          (HasBlockQ.desugar hAlign hΔ hwf hsig hn sc.2.2 hΓ hR)
    | .E_ElseIf hc hy hn _ _ =>
        exact typedIfLet
          (HasTypeQ.desugar hAlign hΔ hwf hsig hc sc.1 hΓ hR)
          (HasBlockQ.desugar hAlign hΔ hwf hsig hy sc.2.1 hΓ hR)
          (HasTypeQ.desugar hAlign hΔ hwf hsig hn sc.2.2 hΓ hR)
    | .E_IfOnly hc hy =>
        have hh := typedIfLet (HasTypeQ.desugar hAlign hΔ hwf hsig hc sc.1 hΓ hR)
          (HasBlockQ.desugar hAlign hΔ hwf hsig hy sc.2 hΓ hR)
          (HasTypeCQ.C_Return (P := desugarProgram op p) (B := B) (Ψ := StoreTy.empty) (C := C) (Γ := fillBuilders Γ Δb) (R := R)
            (HasTypeVQ.V_Const (c := .unit)))
        simpa only [desugarExpr, union_empty_right_nested, Comp.rename, Val.rename, Const.type] using hh
    | .E_ReturnTail h => simpa only [desugarExpr] using HasTypeQ.desugar hAlign hΔ hwf hsig h sc.2 hΓ hR
    | .E_ReturnOther hw h =>
        apply HasTypeCQ.C_Let (HasTypeQ.desugar hAlign hΔ hwf hsig h sc.2 hΓ hR)
        exact .C_Escape (.V_Var rfl (clean_notCont (hR _ rfl))) hw
    | .E_TryResult (ok := ok) (err := err) (cdo := cdo) (cde := cde) (t := t) (e' := et)
        hco hce hno hne hao hae hdata hret he hex =>
        exact tryResult_typed hco hce hno hne hao hae hdata hret
          (HasTypeQ.desugar hAlign hΔ hwf hsig he sc.2 hΓ hR) (HasTypeQ.clean hΔ hwf hsig he sc.2 hΓ hR) hex
    | .E_TryOption (someCon := cs) (noneCon := cn) (cds := cds) (cdn := cdn) (t := t)
        hcs hcn hns hnn has han hdata hret he hex =>
        exact tryOption_typed hcs hcn hns hnn has han hdata hret
          (HasTypeQ.desugar hAlign hΔ hwf hsig he sc.2 hΓ hR) (HasTypeQ.clean hΔ hwf hsig he sc.2 hΓ hR) hex
    | .E_TryResultDie (message := message)
        hco hce hno hne hao hae hdata he hex hd hx hm =>
        have se := by cases message <;> exact sc.2.2.1
        have hc := HasTypeQ.clean hΔ hwf hsig he se hΓ hR
        have he' := HasTypeQ.desugar hAlign hΔ hwf hsig he se hΓ hR
        have hm' : ∀ m, message = some m →
            HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C (hideConts (fillBuilders Γ Δb)) none
              (desugarExpr op .other m) (.base .string) Eff.empty := by
          intro m hh
          simpa only [fillBuilders_hideConts] using HasTypeQ.desugar
            (BuilderCtx.aligned_hideConts hAlign) hΔ hwf hsig (hm m hh)
            (by cases hh; simpa only [hideConts_length] using sc.2.2.2) hΓ.hide (by simp)
        exact tryResultDie_typed hsig hwf hco hce hno hne hao hae hdata he' hc hex (fillBuilders.renOk hAlign) hd hx hm'
    | .E_TryOptionDie (message := message)
        hcs hcn hns hnn has han hdata he hex hx hm =>
        have se := by cases message <;> exact sc.2.1
        have hc := HasTypeQ.clean hΔ hwf hsig he se hΓ hR
        have he' := HasTypeQ.desugar hAlign hΔ hwf hsig he se hΓ hR
        have hm' : ∀ m, message = some m →
            HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C (hideConts (fillBuilders Γ Δb)) none
              (desugarExpr op .other m) (.base .string) Eff.empty := by
          intro m hh
          simpa only [fillBuilders_hideConts] using HasTypeQ.desugar
            (BuilderCtx.aligned_hideConts hAlign) hΔ hwf hsig (hm m hh)
            (by cases hh; simpa only [hideConts_length] using sc.2.2) hΓ.hide (by simp)
        exact tryOptionDie_typed hsig hwf hcs hcn hns hnn has han hdata he' hc hex hx hm'
    | .E_With hr he hb =>
        apply HasTypeCQ.C_Let (HasTypeCQ.weakenEff
          (HasTypeQ.desugar hAlign hΔ hwf hsig he sc.1 hΓ hR) (eff_left _ _))
        apply HasTypeCQ.C_Use (.V_Var rfl (clean_notCont (n := C.length) trivial)) hr
        · apply HasTypeCQ.weakenEff _ ((eff_left _ _).trans (eff_right _ _))
          simpa only [fillBuilders.under_value] using
            (HasBlockQ.desugar (BuilderCtx.aligned_value hAlign _) (BuilderCtx.clean_value hΔ)
              hwf hsig hb sc.2 (hΓ.cons trivial) hR)
        · exact (Eff.mem_union _ _ _).mpr (Or.inr ((Eff.mem_union _ _ _).mpr (Or.inr ((Eff.mem_single _ _).mpr rfl))))
    | .E_Lazy hb =>
        apply HasTypeCQ.C_Lazy
        apply HasTypeCQ.renameId (fillBuilders.renOk hAlign).hide
        simpa only [fillBuilders.empty, List.cons_append, List.nil_append] using HasBlockQ.desugar
          (BuilderCtx.aligned_empty _) (BuilderCtx.clean_empty _) hwf hsig hb
          (by simpa only [Expr.Scoped, hideConts_length] using sc) hΓ.hide (by simp)
    | .E_Handle hb he hc =>
        apply HasTypeCQ.C_Handle (HasBlockQ.desugar hAlign hΔ hwf hsig hb sc.1 hΓ hR)
        · simpa only [desugarClauses_handled, Program.declarationsFor_patternProgram] using he
        · exact HasClausesQ.desugar hAlign hΔ hwf hsig hc sc.2 hΓ hR
            (HasBlockQ.clean hΔ hwf hsig hb sc.1 hΓ hR)
    | .E_Resume hk he =>
        apply HasTypeCQ.C_Let (HasTypeQ.desugar hAlign hΔ hwf hsig he sc.2 hΓ hR)
        exact .C_Resume (by simpa only [List.getElem?_cons_succ] using fillBuilders.value_lookup hAlign hk)
          (.V_Var rfl (clean_notCont (hΓ.cont hk).1))
    | .E_Sub h hl hs _ => exact .C_Sub (HasTypeQ.desugar hAlign hΔ hwf hsig h sc hΓ hR) hl hs resultWF

  theorem HasTypesQ.desugar {Δb : BuilderCtx} {C Γ}
      (hAlign : BuilderCtx.Aligned Γ Δb) (hΔ : BuilderCtx.Clean C.length Δb) (hwf : p.WellFormed)
      (hsig : ∀ b s, B.sig b = some s → s.Scoped) {R es as ε pe}
      (h : HasTypesQ (p.declarationsFor view) B op Q Δb C Γ R es as ε)
      (sc : es.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
      (hR : ∀ r, R = some r → TyOK C.length r) :
      CompTypesQ (desugarProgram op p) B Q C (fillBuilders Γ Δb) R ε (desugarExprs op es) as ∧
        Ty.VarsInList C.length (fun _ => True) as := by
    match h with
    | .nil => exact ⟨.nil, trivial⟩
    | .cons h hs =>
        obtain ⟨hms, hclean⟩ := HasTypesQ.desugar hAlign hΔ hwf hsig hs sc.2 hΓ hR
        exact ⟨.cons (HasTypeCQ.weakenEff (HasTypeQ.desugar hAlign hΔ hwf hsig h sc.1 hΓ hR) (eff_left _ _))
          (hms.weaken (eff_right _ _)), HasTypeQ.clean hΔ hwf hsig h sc.1 hΓ hR, hclean⟩

  theorem HasEachQ.desugar {Δb : BuilderCtx} {C Γ}
      (hAlign : BuilderCtx.Aligned Γ Δb) (hΔ : BuilderCtx.Clean C.length Δb) (hwf : p.WellFormed)
      (hsig : ∀ b s, B.sig b = some s → s.Scoped) {R es a ε pe}
      (h : HasEachQ (p.declarationsFor view) B op Q Δb C Γ R es a ε)
      (sc : es.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
      (hR : ∀ r, R = some r → TyOK C.length r) :
      CompTypesQ (desugarProgram op p) B Q C (fillBuilders Γ Δb) R ε (desugarExprs op es) (List.replicate es.length a) := by
    match h with
    | .nil => exact .nil
    | .cons h hs =>
        simp only [Exprs.length, List.replicate_succ]
        exact .cons (HasTypeCQ.weakenEff (HasTypeQ.desugar hAlign hΔ hwf hsig h sc.1 hΓ hR) (eff_left _ _))
          ((HasEachQ.desugar hAlign hΔ hwf hsig hs sc.2 hΓ hR).weaken (eff_right _ _))

  /-- prior は左で既に通った穴の型。残りの穴と合わせてラムダの全引数を表す。
  右に残る穴の個数が現在の穴の番号となり、非穴の式は全引数の下へ弱化する。 -/
  theorem HasHoleArgsQ.desugar {Δb : BuilderCtx} {C Γ}
      (hAlign : BuilderCtx.Aligned Γ Δb) (hΔ : BuilderCtx.Clean C.length Δb) (hwf : p.WellFormed)
      (hsig : ∀ b s, B.sig b = some s → s.Scoped) {R args as ε pe}
      (h : HasHoleArgsQ (p.declarationsFor view) B op Q Δb C Γ R args as ε)
      (sc : args.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
      (hR : ∀ r, R = some r → TyOK C.length r) (prior : List Ty) :
      CompTypesQ (desugarProgram op p) B Q C (binds (prior ++ args.holeTypes) ++ fillBuilders Γ Δb) R ε
        (desugarHoleArgs op (prior ++ args.holeTypes).length args) as ∧
        Ty.VarsInList C.length (fun _ => True) as := by
    match h with
    | .nil => exact ⟨.nil, trivial⟩
    | .expr (args := rest) he hs =>
        obtain ⟨hms, hc⟩ := HasHoleArgsQ.desugar hAlign hΔ hwf hsig hs sc.2 hΓ hR prior
        have he' := HasTypeQ.desugar hAlign hΔ hwf hsig he sc.1 hΓ hR
        have shifted := he'.rename (RenOk.shift (binds (prior ++ rest.holeTypes)) (fillBuilders Γ Δb))
        exact ⟨.cons (HasTypeCQ.weakenEff (by simpa only [binds_length, HoleArgs.holeTypes] using shifted)
          (eff_left _ _)) (hms.weaken (eff_right _ _)), HasTypeQ.clean hΔ hwf hsig he sc.1 hΓ hR, hc⟩
    | .hole (t := t) (args := rest) hl ha hs =>
        obtain ⟨hms, hc⟩ := HasHoleArgsQ.desugar hAlign hΔ hwf hsig hs sc.2 hΓ hR (prior ++ [t])
        refine ⟨.cons (HasTypeCQ.weakenEff (.C_Return (.V_Sub (.V_Var ?_
          (clean_notCont (scoped_clean sc.1))) hl (Ty.VarsIn.wf _ ha))) (Eff.empty_sub _))
          (by simpa only [HoleArgs.holeTypes, List.append_assoc, List.singleton_append] using hms),
          ha, hc⟩
        simp only [HoleArgs.holeTypes, binds_append, binds_cons, List.append_assoc, List.singleton_append]
        rw [List.getElem?_append_right (by simp [binds_length])]
        simp [binds_length]

  /-- パターンの束縛を保護し、照合対象の let だけを外側の環境に挿入する。 -/
  theorem HasArmsQ.desugar {Δb : BuilderCtx} {C Γ}
      (hAlign : BuilderCtx.Aligned Γ Δb) (hΔ : BuilderCtx.Clean C.length Δb) (hwf : p.WellFormed)
      (hsig : ∀ b s, B.sig b = some s → s.Scoped) {R pos arms a b ε pe}
      (h : HasArmsQ (p.declarationsFor view) B op Q Δb C Γ R pos arms a b ε)
      (sc : arms.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
      (hR : ∀ r, R = some r → TyOK C.length r) (ha : TyOK C.length a) :
      HasTypeArmsQ (desugarProgram op p) B StoreTy.empty Q C (some a :: fillBuilders Γ Δb) R
        (desugarArms op pos arms) a b ε := by
    match h with
    | .nil hw => exact .nil hw
    | .plain _ hp hb hs =>
        have hδ := AltsTy.clean hwf.2.2.1 hp ha
        have hb' := HasBlockQ.desugar (BuilderCtx.aligned_binds hAlign _) (BuilderCtx.all_values hΔ _) hwf hsig hb
          (by simpa [binds_length, hp.2.1] using sc.1) (hΓ.binds hδ) hR
        simp only [fillBuilders.under_binds] at hb'
        have hp' := AltsTy.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hp
        exact .plain hp'
          (HasTypeCQ.weakenEff (HasTypeCQ.shiftAlts hp' hb') (eff_left _ _))
          (HasTypeArmsQ.weakenEff (HasArmsQ.desugar hAlign hΔ hwf hsig hs sc.2 hΓ hR ha) (eff_right _ _))
    | .guarded _ hp hg hb hs =>
        have hδ := AltsTy.clean hwf.2.2.1 hp ha
        have hg' := HasTypeQ.desugar (BuilderCtx.aligned_hideConts (BuilderCtx.aligned_binds hAlign _)) (BuilderCtx.all_values hΔ _) hwf hsig hg
          (by simpa [hideConts_length, binds_length, hp.2.1] using sc.1)
          (hΓ.binds hδ).hide (by simp)
        have hb' := HasBlockQ.desugar (BuilderCtx.aligned_binds hAlign _) (BuilderCtx.all_values hΔ _) hwf hsig hb
          (by simpa [binds_length, hp.2.1] using sc.2.1) (hΓ.binds hδ) hR
        simp only [fillBuilders.under_binds] at hb'
        have hp' := AltsTy.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hp
        simp only [fillBuilders_hideConts, fillBuilders.under_binds] at hg'
        exact .guarded hp' (HasTypeCQ.shiftGuard hp' hg')
          (HasTypeCQ.weakenEff (HasTypeCQ.shiftAlts hp' hb') (eff_left _ _))
          (HasTypeArmsQ.weakenEff (HasArmsQ.desugar hAlign hΔ hwf hsig hs sc.2.2 hΓ hR ha) (eff_right _ _))

  /-- 節の型パラメータの下へ Γ・R・結果型をずらし、引数と継続を加えて本体を移す。 -/
  theorem HasClausesQ.desugar {Δb : BuilderCtx} {C Γ}
      (hAlign : BuilderCtx.Aligned Γ Δb) (hΔ : BuilderCtx.Clean C.length Δb) (hwf : p.WellFormed)
      (hsig : ∀ b s, B.sig b = some s → s.Scoped) {R cs t ε pe}
      (h : HasClausesQ (p.declarationsFor view) B op Q Δb C Γ R cs t ε)
      (sc : cs.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
      (hR : ∀ r, R = some r → TyOK C.length r) (ht : TyOK C.length t) :
      HasTypeClausesQ (desugarProgram op p) B StoreTy.empty Q C (fillBuilders Γ Δb) R
        (desugarClauses op cs) t ε := by
    match h with
    | .nil => exact .nil
    | .cons (ntys := ntys) (sg := sg) hop hnames hn hntys hw hb hs =>
        refine .cons (by exact hop) hnames hn.2 hntys hw ?_ (HasClausesQ.desugar hAlign hΔ hwf hsig hs sc.2 hΓ hR ht)
        have hlen : (sg.tparams ++ C).length = C.length + ntys := by
          simp only [List.length_append]; omega
        have hsg := opSig_clean hwf hsig hop
        have hparams : Ty.VarsInList (sg.tparams ++ C).length (fun _ => True) sg.params :=
          Ty.VarsInList.mono (by simp only [List.length_append]; omega) (fun _ h => h) _ hsg.1
        have hret : TyOK (sg.tparams ++ C).length sg.ret :=
          Ty.VarsIn.mono (by simp only [List.length_append]; omega) (fun _ h => h) _ hsg.2
        have ht' : TyOK (sg.tparams ++ C).length (t.shift ntys 0) := by
          rw [hlen]; exact shift_clean ntys t ht
        have hΓ' : EnvClean (sg.tparams ++ C).length (shiftEnv ntys Γ) := by
          rw [hlen]; exact hΓ.shift ntys
        apply HasTypeCQ.renameId (RenOk.up_id (some (.cont sg.ret (t.shift ntys 0) (Eff.shift ntys 0 ε)) :: binds sg.params)
          ((fillBuilders.renOk hAlign).shiftE ntys))
        simpa only [fillBuilders.empty, List.cons_append, List.nil_append] using HasBlockQ.desugar
          (BuilderCtx.aligned_empty _) (BuilderCtx.clean_empty _) hwf hsig hb
          (by simpa only [hlen, List.length_cons, List.length_append, binds_length, shiftEnv_length, ← hn.2,
            Nat.add_comm, Nat.add_left_comm, Nat.add_assoc] using sc.1)
          ((hΓ'.binds hparams).consCont hret ht') (by
          intro r he
          obtain ⟨r', hr', rfl⟩ := Option.map_eq_some_iff.mp he
          rw [hlen]; exact shift_clean ntys r' (hR r' hr'))

  theorem HasBlockQ.desugar {Δb : BuilderCtx} {C Γ}
      (hAlign : BuilderCtx.Aligned Γ Δb) (hΔ : BuilderCtx.Clean C.length Δb) (hwf : p.WellFormed)
      (hsig : ∀ b s, B.sig b = some s → s.Scoped) {R pos body a ε pe}
      (h : HasBlockQ (p.declarationsFor view) B op Q Δb C Γ R pos body a ε)
      (sc : body.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
      (hR : ∀ r, R = some r → TyOK C.length r) :
      HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C (fillBuilders Γ Δb) R (desugarBlock op pos body) a ε := by
    have resultWF := Ty.VarsIn.wf _ (HasBlockQ.clean hΔ hwf hsig h sc hΓ hR)
    match h with
    | .B_LastPat _ _ hp hex he =>
        have ha := HasTypeQ.clean hΔ hwf hsig he sc.2 hΓ hR
        apply HasTypeCQ.C_Let (HasTypeQ.desugar hAlign hΔ hwf hsig he sc.2 hΓ hR)
        apply HasTypeCQ.C_Match (.V_Var rfl (clean_notCont ha))
        · exact HasTypeArmsQ.mkArm_cons (PatTy.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hp)
            (HasTypeCQ.weakenEff (.C_Return .V_Const) (Eff.empty_sub _)) (.nil trivial)
        · simpa only [unguardedPats_mkArm_cons, unguardedPats] using
            Exhaustive.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hex.exhaustive
    | .B_BindPat (δ := δ) (rest := rest) _ _ hp hex he hb =>
        have ha := scoped_clean sc.1
        have hδ := PatTy.clean hwf.2.2.1 hp ha
        have scb : Block.Scoped C.length pe (binds δ ++ Γ).length rest :=
          by simpa [binds_length, hp.length_eq, Pattern.binders] using sc.2.2
        have hb' := HasBlockQ.desugar (BuilderCtx.aligned_binds hAlign _) (BuilderCtx.all_values hΔ _) hwf hsig hb scb (hΓ.binds hδ) hR
        simp only [fillBuilders.under_binds] at hb'
        have hc := HasBlockQ.clean (BuilderCtx.all_values hΔ _) hwf hsig hb scb (hΓ.binds hδ) hR
        apply typedLet (HasTypeQ.desugar hAlign hΔ hwf hsig he sc.2.1 hΓ hR)
        apply HasTypeCQ.C_Match (.V_Var rfl (clean_notCont ha))
        · exact HasTypeArmsQ.mkArm_cons (PatTy.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hp)
            (HasTypeCQ.shiftPattern (PatTy.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hp) hb') (.nil (Ty.VarsIn.wf _ hc))
        · simpa only [unguardedPats_mkArm_cons, unguardedPats] using
            Exhaustive.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hex.exhaustive
    | .B_BuilderBind hk hc _ hr hb =>
        have ih := HasBlockQ.desugar (BuilderCtx.aligned_builder hAlign _) (BuilderCtx.clean_builder hΔ hc)
          hwf hsig hb sc.2.2
          (by intro i t hi; cases i with
              | zero => simp at hi
              | succ i => exact hΓ i t hi) hR
        cases hk
        exact builderBlock_desugar_typed hr hc ih
    | .B_Empty =>
        exact .C_Return .V_Const
    | .B_Last h =>
        exact HasTypeQ.desugar hAlign hΔ hwf hsig h sc hΓ hR
    | .B_LastBind h =>
        exact .C_Let (HasTypeQ.desugar hAlign hΔ hwf hsig h sc.2 hΓ hR)
          (HasTypeCQ.weakenEff (.C_Return .V_Const) (Eff.empty_sub _))
    | .B_LastDiscard h =>
        exact .C_Let (HasTypeQ.desugar hAlign hΔ hwf hsig h sc hΓ hR)
          (HasTypeCQ.weakenEff (.C_Return .V_Const) (Eff.empty_sub _))
    | .B_Bind h hb =>
        exact typedLet (HasTypeQ.desugar hAlign hΔ hwf hsig h sc.2.1 hΓ hR)
          (by simpa only [fillBuilders.under_value] using
            HasBlockQ.desugar (BuilderCtx.aligned_value hAlign _) (BuilderCtx.clean_value hΔ) hwf hsig hb sc.2.2 (hΓ.cons (scoped_clean sc.1)) hR)
    | .B_Discard h hb =>
        exact typedLet (HasTypeQ.desugar hAlign hΔ hwf hsig h sc.1 hΓ hR)
          (HasTypeCQ.shiftOne (HasBlockQ.desugar hAlign hΔ hwf hsig hb sc.2 hΓ hR))
    | .B_Seq h _ hb =>
        exact typedLet (HasTypeQ.desugar hAlign hΔ hwf hsig h sc.1 hΓ hR)
          (HasTypeCQ.shiftOne (HasBlockQ.desugar hAlign hΔ hwf hsig hb sc.2 hΓ hR))
    | .B_Sub h hl hs hw =>
        exact .C_Sub (HasBlockQ.desugar hAlign hΔ hwf hsig h sc hΓ hR) hl hs resultWF
end

namespace HasType
/-- 空の構築器文脈では、従来の通常環境で型保存を得る。 -/
theorem desugar (hwf : p.WellFormed)
    (hsig : ∀ b s, B.sig b = some s → s.Scoped) {C Γ R pos e a ε pe}
    (h : HasTypeQ (p.declarationsFor view) B op Q [] C Γ R pos e a ε)
    (sc : e.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
    (hR : ∀ r, R = some r → TyOK C.length r) :
    HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C Γ R (desugarExpr op pos e) a ε := by
  simpa only [fillBuilders.empty] using
    HasTypeQ.desugar (BuilderCtx.aligned_empty _) (BuilderCtx.clean_empty _) hwf hsig h sc hΓ hR
end HasType
namespace HasBlock
/-- 空の構築器文脈では、従来の通常環境でブロックの型保存を得る。 -/
theorem desugar (hwf : p.WellFormed)
    (hsig : ∀ b s, B.sig b = some s → s.Scoped) {C Γ R pos body a ε pe}
    (h : HasBlockQ (p.declarationsFor view) B op Q [] C Γ R pos body a ε)
    (sc : body.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
    (hR : ∀ r, R = some r → TyOK C.length r) :
    HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C Γ R (desugarBlock op pos body) a ε := by
  simpa only [fillBuilders.empty] using
    HasBlockQ.desugar (BuilderCtx.aligned_empty _) (BuilderCtx.clean_empty _) hwf hsig h sc hΓ hR
end HasBlock

end Benitoite.Surface
