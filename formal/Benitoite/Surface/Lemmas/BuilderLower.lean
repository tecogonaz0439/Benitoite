import Benitoite.Surface.BuilderLower
import Benitoite.Surface.Lemmas.Builders
import Benitoite.Surface.Lemmas.Sequence

/-! 宣言表で検査した参照先から専用操作の展開を型付けする。
対応する規則は設計書 01-12「構築器の専用操作と脱糖」である。 -/
namespace Benitoite.Surface
open Benitoite.Release

variable {view : CoverageView}
variable {p : Program} {B : Builtins} {opPrim : OpPrim} {C : List TParam} {Q : NoFailCtx}

/-- 純粋な合成は追記する通常値だけを受け取り、セルに触れない。 -/
theorem builderCombine_typed {r : BuilderRefs} {Γ R old arg}
    (hr : r.PureOk (p.declarationsFor view) B C Q) (o : BuilderOp)
    (ho : o = .append ∨ o = .appendAll)
    (hold : HasTypeVQ (desugarProgram opPrim p) B StoreTy.empty Q C Γ old r.kind.contents)
    (harg : HasTypeVsQ (desugarProgram opPrim p) B StoreTy.empty Q C Γ [arg] (o.params r.kind)) :
    HasTypeCQ (desugarProgram opPrim p) B StoreTy.empty Q C Γ R
      (builderCombine o r old arg) r.kind.contents Eff.empty := by
  rcases ho with rfl | rfl <;> cases r with
  | string c add join len =>
      cases harg with
      | cons ha hs =>
        first
        | exact hr.1.apply (.cons hold (.cons ha .nil))
        | exact .C_Let (hr.2.1.apply (.cons ha (.cons .V_Const .nil)))
            (hr.1.apply (.cons (hold.rename (RenOk.shift [some (.base .string)] Γ))
              (.cons (.V_Var rfl (by intro b t e h; cases h)) .nil)))
  | list t c append cat len =>
      cases harg with
      | cons ha hs => first
        | exact hr.1.apply (.cons hold (.cons ha .nil))
        | exact hr.2.1.apply (.cons hold (.cons ha .nil))
  | bytes c empty fromList cat len =>
      cases harg with
      | cons ha hs =>
        first
        | exact .C_Let (hr.2.1.apply (.cons (.V_List (.cons ha .nil) (by trivial)) .nil))
            (hr.2.2.1.apply (.cons (hold.rename (RenOk.shift [some .bytes] Γ))
              (.cons (.V_Var rfl (by intro b t e h; cases h)) .nil)))
        | exact hr.2.2.1.apply (.cons hold (.cons ha .nil))

/-- get と set を既存の State 付き規則へ接続する。 -/
theorem builderFinish_typed {r : BuilderRefs} {Γ R i args}
    (hr : r.cells.Ok B C Q r.kind ∧ r.PureOk (p.declarationsFor view) B C Q)
    (hc : HasTypeVQ (desugarProgram opPrim p) B StoreTy.empty Q C Γ (.var i) r.kind.cell)
    (o : BuilderOp)
    (ha : HasTypeVsQ (desugarProgram opPrim p) B StoreTy.empty Q C Γ args (o.params r.kind)) :
    HasTypeCQ (desugarProgram opPrim p) B StoreTy.empty Q C Γ R
      (builderFinish o i r args) (o.result r.kind) (Eff.single stateEff) := by
  cases o with
  | copy => cases ha; exact hr.1.2.2.2.2.1.apply (.cons hc .nil)
  | length =>
      cases ha
      apply HasTypeCQ.C_Let (hr.1.2.2.2.2.1.apply (.cons hc .nil))
      have hl : r.lengthRef.Ok (p.declarationsFor view) B C Q r.kind.lengthNames [r.kind.contents] (.base .integer) := by
        cases r with
        | string _ _ _ _ => exact hr.2.2.2
        | list _ _ _ _ _ => exact hr.2.2.2
        | bytes _ _ _ _ _ => exact hr.2.2.2.2
      exact HasTypeCQ.weakenEff (hl.apply (.cons (.V_Var rfl (by cases r <;> intro b t e h <;> cases h)) .nil)) (Eff.empty_sub _)
  | append =>
      cases ha with
      | cons harg hnil =>
        cases hnil
        apply HasTypeCQ.C_Let (hr.1.2.2.2.2.1.apply (.cons hc .nil))
        apply HasTypeCQ.C_Let (HasTypeCQ.weakenEff (builderCombine_typed hr.2 .append (Or.inl rfl)
          (.V_Var rfl (by cases r <;> intro b t e h <;> cases h))
          (.cons (harg.rename (RenOk.shift [some r.kind.contents] Γ)) .nil)) (Eff.empty_sub _))
        exact hr.1.2.2.2.2.2.apply (.cons
          (by simpa only [Val.rename, List.length_cons, List.length_nil, List.cons_append, List.nil_append, Nat.zero_add] using (hc.rename (RenOk.shift [some r.kind.contents, some r.kind.contents] Γ)))
          (.cons (.V_Var rfl (by cases r <;> intro b t e h <;> cases h)) .nil))
  | appendAll =>
      cases ha with
      | cons harg hnil =>
        cases hnil
        apply HasTypeCQ.C_Let (hr.1.2.2.2.2.1.apply (.cons hc .nil))
        apply HasTypeCQ.C_Let (HasTypeCQ.weakenEff (builderCombine_typed hr.2 .appendAll (Or.inr rfl)
          (.V_Var rfl (by cases r <;> intro b t e h <;> cases h))
          (.cons (harg.rename (RenOk.shift [some r.kind.contents] Γ)) .nil)) (Eff.empty_sub _))
        exact hr.1.2.2.2.2.2.apply (.cons
          (by simpa only [Val.rename, List.length_cons, List.length_nil, List.cons_append, List.nil_append, Nat.zero_add] using (hc.rename (RenOk.shift [some r.kind.contents, some r.kind.contents] Γ)))
          (.cons (.V_Var rfl (by cases r <;> intro b t e h <;> cases h)) .nil))

/-- 操作の結果の型は内容の型から範囲を保つ。 -/
theorem BuilderOp.result_clean {k : BuilderKind} {n} (o : BuilderOp)
    (h : TyOK n k.contents) : TyOK n (o.result k) := by
  cases o <;> first | exact h | trivial

/-- 通常引数の型も、内容の型から範囲を保つ。 -/
theorem BuilderOp.params_clean {k : BuilderKind} {n} (o : BuilderOp)
    (h : TyOK n k.contents) : Ty.VarsInList n (fun _ => True) (o.params k) := by
  cases o <;> cases k <;> simp_all [BuilderOp.params, BuilderKind.item, BuilderKind.contents, TyOK, Ty.VarsInList, Ty.VarsIn]

/-- 合成が参照する型引数は、構文に保持した参照先の範囲内である。 -/
theorem builderCombine_scoped {nt pe r old arg}
    (hr : r.ForRefs (Val.VarsIn nt pe)) (ho : Val.VarsIn nt pe old)
    (ha : Val.VarsIn nt pe arg) (o : BuilderOp) :
    Comp.VarsIn nt pe (builderCombine o r old arg) := by
  cases o <;> cases r <;> simp only [builderCombine]
  all_goals first
    | exact ho
    | exact ⟨hr.2.1, ho, ha, trivial⟩
    | exact ⟨hr.2.2.1, ho, ha, trivial⟩
    | exact ⟨hr.2.2.2.1, ho, ha, trivial⟩
    | exact ⟨⟨hr.2.2.1, ha, trivial, trivial⟩, hr.2.1,
        Val.VarsIn.renameScoped _ _ ho, trivial, trivial⟩
    | exact ⟨⟨hr.2.2.1, ⟨ha, trivial⟩, trivial⟩, hr.2.2.2.1,
        Val.VarsIn.renameScoped _ _ ho, trivial, trivial⟩

/-- get/set の追加と番号の移動は型引数の範囲を変えない。 -/
theorem builderFinish_scoped {nt pe r args i}
    (hr : r.ForRefs (Val.VarsIn nt pe)) (ha : Val.VarsInList nt pe args) (o : BuilderOp) :
    Comp.VarsIn nt pe (builderFinish o i r args) := by
  cases o <;> cases args with
  | nil => first
    | exact ⟨hr.1.2.1, trivial, trivial⟩
    | exact ⟨⟨hr.1.2.1, trivial, trivial⟩,
        (by cases r <;> first | exact hr.2.2.2 | exact hr.2.2.2.2), trivial, trivial⟩
    | trivial
  | cons arg rest => cases rest with
    | cons _ _ => trivial
    | nil => first
      | trivial
      | exact ⟨⟨hr.1.2.1, trivial, trivial⟩,
          builderCombine_scoped hr (by trivial) (Val.VarsIn.renameScoped _ _ ha.1) _,
          hr.1.2.2, trivial, trivial, trivial⟩

/-- 通常引数を一度ソース順に束縛してから、同じ番号のセルを読む。
生成 let の個数だけセル番号をずらし、State を保存する。 -/
theorem builderOp_desugar_typed {Γ Δ R i r o ε ms}
    (hAlign : BuilderCtx.Aligned Γ Δ)
    (hr : BuilderRefs.Ok (p.declarationsFor view) B C Q Δ i r)
    (hm : CompTypesQ (desugarProgram opPrim p) B Q C (fillBuilders Γ Δ) R ε ms (o.params r.kind))
    (hc : Ty.VarsInList C.length (fun _ => True) (o.params r.kind)) :
    HasTypeCQ (desugarProgram opPrim p) B StoreTy.empty Q C (fillBuilders Γ Δ) R
      (sequence ms (builderFinish o (i + ms.length) r))
      (o.result r.kind) (Eff.union ε (Eff.single stateEff)) := by
  apply sequence_typed (hm.weaken (eff_left _ _)) hc
  intro vs hv
  apply HasTypeCQ.weakenEff (builderFinish_typed hr.2 ?_ o hv) (eff_right _ _)
  simpa only [Val.rename, binds_length, hm.length] using
    (fillBuilders.cell_typed hAlign hr.1).rename
      (RenOk.shift (binds (o.params r.kind)) (fillBuilders Γ Δ))

/-- 空の通常値の初期化には State も局所変数も要らない。 -/
theorem builderInit_typed {r : BuilderRefs} {Γ R}
    (hr : r.PureOk (p.declarationsFor view) B C Q) (hw : TyOK C.length r.kind.contents) :
    HasTypeCQ (desugarProgram opPrim p) B StoreTy.empty Q C Γ R
      (builderInit r) r.kind.contents Eff.empty := by
  cases r with
  | string => exact .C_Return .V_Const
  | list => exact .C_Return (.V_List .nil (Ty.VarsIn.wf _ hw))
  | bytes => exact hr.1.apply .nil

/-- new の参照先の存在は宣言の検査から得る。新しい組み込みの仮定は要らない。 -/
theorem builderNew_typed {r : BuilderRefs} {Γ R}
    (hr : r.cells.Ok B C Q r.kind ∧ r.PureOk (p.declarationsFor view) B C Q) (hw : TyOK C.length r.kind.contents) :
    HasTypeCQ (desugarProgram opPrim p) B StoreTy.empty Q C Γ R
      (builderNew r) r.kind.cell (Eff.single stateEff) := by
  rw [builderNew]
  apply HasTypeCQ.C_Let (HasTypeCQ.weakenEff (builderInit_typed hr.2 hw) (Eff.empty_sub _))
  have hc : ∀ b a e, r.kind.contents ≠ .cont b a e := by cases r <;> intro b a e h <;> cases h
  exact hr.1.2.2.2.1.apply (.cons (.V_Var rfl hc) .nil)

/-- 宣言による一つのセルと、後続の分類表の先頭を同じ let で接続する。 -/
theorem builderBlock_desugar_typed {r : BuilderRefs} {Γ Δ R body a ε}
    (hr : BuilderRefs.Ok (p.declarationsFor view) B C Q (some r.kind :: Δ) 0 r)
    (hw : TyOK C.length r.kind.contents)
    (hb : HasTypeCQ (desugarProgram opPrim p) B StoreTy.empty Q C
      (fillBuilders (none :: Γ) (some r.kind :: Δ)) R body a ε) :
    HasTypeCQ (desugarProgram opPrim p) B StoreTy.empty Q C (fillBuilders Γ Δ) R
      (.letIn (builderNew r) body) a (Eff.union (Eff.single stateEff) ε) :=
  typedLet (builderNew_typed hr.2 hw) hb

/-- 初期化の参照は型と行の範囲も保つ。 -/
theorem builderNew_scoped {r : BuilderRefs} {nt pe}
    (hr : r.ForRefs (Val.VarsIn nt pe)) : Comp.VarsIn nt pe (builderNew r) := by
  cases r <;> simp_all [builderNew, builderInit, BuilderRefs.ForRefs, Comp.VarsIn,
    Val.VarsIn, Val.VarsInList, BuilderRefs.cells]

end Benitoite.Surface
