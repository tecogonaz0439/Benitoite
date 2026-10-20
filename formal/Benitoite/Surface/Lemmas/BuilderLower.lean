import Benitoite.Surface.BuilderLower
import Benitoite.Surface.Lemmas.Builders
import Benitoite.Surface.Lemmas.Sequence

/-! 分類表の種類と通常引数の導出から専用操作の展開を型付けする。
対応する規則は設計書 01-12「構築器の専用操作と脱糖」である。 -/
namespace Benitoite.Surface
open Benitoite.Release

variable {p : Program} {B : Builtins} {opPrim : OpPrim} {C : List TParam} {Q : NoFailCtx}

/-- 専用操作自身の効果は空であり、引数の効果は sequence で保つ。 -/
theorem builderFinish_typed {k : BuilderKind} {Γ Δ R i args}
    (hw : Ty.WF C.length k.contents)
    (hi : Δ.kindAt i = some k) (o : BuilderOp)
    (ha : HasTypeVsQ (desugarProgram opPrim p) B StoreTy.empty Q C Γ args (o.params k)) :
    HasTypeCQ (desugarProgram opPrim p) B StoreTy.empty Q C Γ R
      (builderFinish o i k args) (o.result k) Eff.empty Δ :=
  .C_BuilderOp hw (.bound hi) ha

/-- 操作の結果の型は内容の型から範囲を保つ。 -/
theorem BuilderOp.result_clean {k : BuilderKind} {n} (o : BuilderOp)
    (h : TyOK n k.contents) : TyOK n (o.result k) := by
  cases o <;> first | exact h | trivial

/-- 通常引数の型も、内容の型から範囲を保つ。 -/
theorem BuilderOp.params_clean {k : BuilderKind} {n} (o : BuilderOp)
    (h : TyOK n k.contents) : Ty.VarsInList n (fun _ => True) (o.params k) := by
  cases o <;> cases k <;> simp_all [BuilderOp.params, BuilderKind.item, BuilderKind.contents, TyOK, Ty.VarsInList, Ty.VarsIn]

/-- 通常引数を一度ソース順に束縛し、専用番号も同じ個数だけ移す。 -/
theorem builderOp_desugar_typed {Γ Δ R i k o ε ms}
    (hr : BuilderCtx.kindAt Δ i = some k)
    (hw : TyOK C.length k.contents)
    (hm : CompTypesQ (desugarProgram opPrim p) B Q C Γ R ε ms (o.params k) Δ.toLocal)
    (hc : Ty.VarsInList C.length (fun _ => True) (o.params k)) :
    HasTypeCQ (desugarProgram opPrim p) B StoreTy.empty Q C Γ R
      (sequence ms (builderFinish o (i + ms.length) k))
      (o.result k) ε Δ.toLocal := by
  apply sequence_typed hm hc
  intro vs hv
  apply HasTypeCQ.weakenEff (builderFinish_typed (Ty.VarsIn.wf _ hw) ?_ o hv) (Eff.empty_sub _)
  rw [hm.length, LocalCtx.kindAt_extend, ite_eq_right (by omega), Nat.add_sub_cancel, BuilderCtx.toLocal_kindAt]
  exact hr

/-- Γ の none と Δ の専用束縛を、同じ builderLet の一段へ接続する。 -/
theorem builderBlock_desugar_typed {k : BuilderKind} {Γ R body a ε} {Δ : BuilderCtx}
    (hw : TyOK C.length k.contents)
    (hb : HasTypeCQ (desugarProgram opPrim p) B StoreTy.empty Q C
      (none :: Γ) R body a ε (some k :: Δ.toLocal)) :
    HasTypeCQ (desugarProgram opPrim p) B StoreTy.empty Q C Γ R
      (.builderLet k body) a ε Δ.toLocal :=
  .C_BuilderLet (Ty.VarsIn.wf _ hw) hb

/-- 専用番号の範囲は表層から受け取り、通常引数には専用参照を含めない。 -/
theorem builderFinish_scoped {nt pe k args i depth}
    (hk : match k with | .list t => Ty.VarsIn nt pe t | _ => True)
    (hi : i < depth) (ha : Val.VarsInList nt pe args) (o : BuilderOp) :
    Comp.VarsIn nt pe (builderFinish o i k args) depth :=
  ⟨hk, hi, Benitoite.Release.Val.VarsInList.widen (Nat.le_refl _) (Nat.zero_le _) _ ha⟩

end Benitoite.Surface
