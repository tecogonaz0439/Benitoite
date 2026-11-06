import Benitoite.Release.Refinement.Surface.Property1
import Benitoite.Release.Refinement.Surface.OpenSurfaceProperty1

/-!
# 表層のプログラムの型付けと、定義・実装の型の保存

関数の定義は宣言の依存列の引数を順に束縛した文脈で、本体を末尾位置で型付ける（設計書 01-12「トップレベルの関数」）。
実装のメソッドは型クラスの宣言を実装の型で具体化した依存列で、上位の辞書は実装の辞書の引数の文脈で型付ける
（同「型クラス」D-Impl）。フィールドを取り出す関数は脱糖が生成する。
-/

namespace Benitoite.Release.Refinement.Surface

variable {P : Refinement.Program} {B : Builtins}

/-- 依存列の引数を順に束縛し、done の結果型を戻り値型として本体を末尾位置で型付ける。 -/
inductive BodyTy (D : Declarations) (B : Builtins) (opPrim : OpPrim) (Q : NoFailCtx) :
    TypeCtx → Ctx → List Pred → Tel → Block → Prop
  | done {C Γ Φ a e body} : HasBlockQ D B opPrim Q [] C Γ Φ (some a) .tail body a e →
      BodyTy D B opPrim Q C Γ Φ (.done a e) body
  | param {C Γ Φ name a rest body} : BodyTy D B opPrim Q C (Γ.extend a) (Φ.map Pred.lift) rest body →
      BodyTy D B opPrim Q C Γ Φ (.param name a rest) body

/-- 範囲文脈が空なら既存の判断を使い、非空なら開いた表層の有限な導出を使う。 -/
def BodyTyR (D : Declarations) (B : Builtins) (op : OpPrim) (Q : NoFailCtx)
    (ks : List Scope.Domain.Kind) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (t : Tel) (body : Block) : Prop :=
  if ks = [] then BodyTy D B op Q C Γ Φ t body else OpenSurface.BodyTy D B ks op Q C Γ Φ t body

/-- 範囲パラメータのない本体は、元の表層の本体の判断と同値である。 -/
@[simp] theorem bodyTyR_nil {D B op Q C Γ Φ t body} :
    BodyTyR D B op Q [] C Γ Φ t body ↔ BodyTy D B op Q C Γ Φ t body := by
  simp [BodyTyR]

/-- 関数の定義の型付け。 -/
def Def.WellTyped (D : Declarations) (B : Builtins) (opPrim : OpPrim) (d : Def) : Prop :=
  NamesWF d.coreNames d.coreParams ∧
  Ty.HasKind D.core (TypeCtx.kinds d.tparams) (.dependentFn d.toFunDecl.tel) .value ∧
  Ty.AnnotationR D.core d.rangeParams d.tparams [] (.dependentFn d.toFunDecl.tel) ∧
  BodyTyR D B opPrim (QTel d.toFunDecl.tel) d.rangeParams d.tparams [] [] d.toFunDecl.tel d.body

/-- 本体のソース照合だけに使う view を替えた宣言の表。 -/
def Declarations.withView (D : Declarations) (view : CoverageView) : Declarations := { D with view := view }

/-- 実装の型付け。核の実装の型付けと同じ欄を、表層の本体と辞書の根拠で述べる。メソッドの本体はメソッドごとの
view で型付ける。 -/
def ImplDecl.WellTyped (D : Declarations) (B : Builtins) (opPrim : OpPrim) (id : ImplDecl)
    (views : MethName → CoverageView := fun _ => D.view) : Prop :=
  ∃ cd, D.classes id.cls = some cd ∧
    (∀ m, (id.methods m).isSome = (cd.methods m).isSome) ∧
    (∀ s, (id.supers s).isSome = decide (s ∈ cd.supers)) ∧
    Ty.HasKind D.core (TypeCtx.kinds (TypeCtx.values id.tparams)) id.target cd.argumentKind ∧
    TypeAnnotations D.core (TypeCtx.values id.tparams) [] id.dictTys ∧
    (∀ m ms, cd.methods m = some ms → ∃ body, id.methods m = some body ∧
      NamesWF ms.names ms.params ∧
      BodyTy (D.withView (views m)) B opPrim (QTel ms.tel) (ms.tparams ++ TypeCtx.values id.tparams)
        (bindParams [] (id.dictTys.map (Ty.shift ms.tparams.length 0))) []
        (Tel.shiftV id.dictTys.length 0 (Tel.bind (typeEnvAt ms.tparams.length [id.target] []) ms.tel)) body) ∧
    (∀ s ∈ cd.supers, ∃ u, id.supers s = some u ∧
      DictEv.HasType D B (TypeCtx.values id.tparams) (bindParams [] id.dictTys) u (.dict s id.target))

theorem BodyTy.desugar {D op Q C Γ Φ t body} (h : BodyTy D B op Q C Γ Φ t body) (hR : D.Realizes P)
    (hA : Builtins.ValueAssumptions P B) :
    TelBodyTy P B StoreTy.empty Q C Γ Φ t (desugarBlock op .tail body) := by
  induction h with
  | done hb => exact .done (hb.desugar hR hA)
  | param _ ih => exact .param ih

/-- 範囲のない定義の条件は、元の名前・kind・注釈・本体の四条件へ戻る。 -/
theorem Def.wellTyped_no_ranges {D op d} (hr : d.rangeParams = []) :
    Def.WellTyped D B op d ↔ NamesWF d.coreNames d.coreParams ∧
      Ty.HasKind D.core (TypeCtx.kinds d.tparams) (.dependentFn d.toFunDecl.tel) .value ∧
      Ty.Annotation D.core d.tparams [] (.dependentFn d.toFunDecl.tel) ∧
      BodyTy D B op (QTel d.toFunDecl.tel) d.tparams [] [] d.toFunDecl.tel d.body := by
  simp only [Def.WellTyped, hr, Ty.annotationR_nil, bodyTyR_nil]

/-- 表層の本体の一度の導出から、核の全適格具体化の判断を得る。 -/
theorem BodyTyR.desugar {D op Q ks C Γ Φ t body} (h : BodyTyR D B op Q ks C Γ Φ t body)
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) :
    TelBodyTyR P B StoreTy.empty Q ks C Γ Φ t (desugarBlock op .tail body) := by
  by_cases hk : ks = []
  · subst ks
    exact telBodyTyR_nil.mpr ((bodyTyR_nil.mp h).desugar hR hA)
  · exact (by simpa only [BodyTyR, hk, ite_false] using h : OpenSurface.BodyTy D B ks op Q C Γ Φ t body).desugar hR hA

theorem Def.WellTyped.desugar {D op d} (h : Def.WellTyped D B op d) (hR : D.Realizes P)
    (hA : Builtins.ValueAssumptions P B) : Refinement.Def.WellTyped P B (desugarDef op d) := by
  obtain ⟨hn, hk, ha, hb⟩ := h
  exact ⟨hn, hk.sameTypes hR.types, ⟨ha.wf, ha.sorted, ha.declared.sameTypes hR.types⟩,
    hb.desugar hR hA⟩

theorem ImplDecl.WellTyped.desugar {D op id views} (h : ImplDecl.WellTyped D B op id views)
    (hR : ∀ v, (D.withView v).Realizes P) (hD : D.Realizes P)
    (hA : Builtins.ValueAssumptions P B) : Refinement.ImplDecl.WellTyped P B (desugarImpl op id) := by
  obtain ⟨cd, hc, hm, hs, hk, ht, hb, hsup⟩ := h
  have hdt : (desugarImpl op id).dictTys = id.dictTys := rfl
  refine ⟨cd, hD.classes ▸ hc, fun m => by simpa [desugarImpl] using hm m, fun s => by simpa [desugarImpl] using hs s,
    hk.sameTypes hD.types, ht.sameTypes hD.types, ?_, ?_⟩
  · intro m ms hms
    obtain ⟨body, hbody, hn, hbt⟩ := hb m ms hms
    exact ⟨_, by simp [desugarImpl, hbody], hn, hbt.desugar (hR (views m)) hA⟩
  · intro s hsm
    obtain ⟨u, hu, hut⟩ := hsup s hsm
    exact ⟨u.toVal, by simp [desugarImpl, hu], hut.core hD⟩

end Benitoite.Release.Refinement.Surface
