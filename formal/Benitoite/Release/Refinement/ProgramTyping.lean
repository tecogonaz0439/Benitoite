import Benitoite.Release.Refinement.Typing
import Benitoite.Release.Refinement.VarianceValidation

/-! # 定義・実装・プログラムの型付け（設計書 01-12「型付け規則」） -/
namespace Benitoite.Release.Refinement
noncomputable section

/-- 依存列と非依存の呼出し側で、同じ行変数の条件を読む。 -/
theorem QTel_signatureTel (ns : List String) (ps : List Ty) (r : Ty) (e : Eff)
    (hn : NamesWF ns ps) :
    QTel (signatureTel ns ps r e) = Qsig ps r e := by
  induction ns generalizing ps with
  | nil =>
    have hp : ps = [] := List.eq_nil_of_length_eq_zero hn.1.symm
    subst ps
    funext i
    apply propext
    simp [signatureTel, QTel, Qsig, QTys, Qempty]
  | cons n ns ih =>
    cases ps with
    | nil => simp [NamesWF] at hn
    | cons a ps =>
      have hns : NamesWF ns ps := ⟨by simpa using hn.1, hn.2.tail⟩
      funext i
      apply propext
      simp only [signatureTel, QTel, ih ps hns, Qsig, QTys]
      exact or_assoc.symm

theorem Def.QTel_eq_Qsig (d : Def) (hn : NamesWF d.names d.params) :
    QTel d.tel = Qsig d.params d.ret d.eff :=
  QTel_signatureTel d.names d.params d.ret d.eff hn

theorem MethSig.QTel_eq_Qsig (ms : MethSig) (hn : NamesWF ms.names ms.params) :
    QTel ms.tel = Qsig ms.params ms.ret ms.eff :=
  QTel_signatureTel ms.names ms.params ms.ret ms.eff hn

/-- 各引数を順に束縛し、done の結果型を return 契約にする。 -/
def Def.WellTyped (P : Program) (B : Builtins) (d : Def) : Prop :=
  NamesWF d.names d.params ∧
  Ty.HasKind P (TypeCtx.kinds d.tparams) (.dependentFn d.tel) .value ∧
  Ty.Annotation P d.tparams [] (.dependentFn d.tel) ∧
  TelBodyTy P B StoreTy.empty (QTel d.tel)
    d.tparams [] [] d.tel d.body

/-- 型クラスの引数の型代入の後、実装の辞書の個数だけ値参照を移す。 -/
def ImplDecl.WellTyped (P : Program) (B : Builtins) (id : ImplDecl) : Prop :=
  ∃ cd, P.classes id.cls = some cd ∧
    (∀ m, (id.methods m).isSome = (cd.methods m).isSome) ∧
    (∀ s, (id.supers s).isSome = decide (s ∈ cd.supers)) ∧
    Ty.HasKind P (TypeCtx.kinds (TypeCtx.values id.tparams)) id.target cd.argumentKind ∧
    TypeAnnotations P (TypeCtx.values id.tparams) [] id.dictTys ∧
    (∀ m ms, cd.methods m = some ms → ∃ body, id.methods m = some body ∧
      NamesWF ms.names ms.params ∧
      let θ := typeEnvAt ms.tparams.length [id.target] []
      let t := Tel.bind θ ms.tel
      let C := ms.tparams ++ TypeCtx.values id.tparams
      let Γ := bindParams [] (id.dictTys.map (Ty.shift ms.tparams.length 0))
      let t' := Tel.shiftV id.dictTys.length 0 t
      TelBodyTy P B StoreTy.empty (QTel ms.tel) C Γ [] t' body) ∧
    (∀ s ∈ cd.supers, ∃ u, id.supers s = some u ∧
      HasTypeV P B StoreTy.empty (TypeCtx.values id.tparams) (bindParams [] id.dictTys) []
        u (.dict s id.target))

/-- 呼出し規則 C-Meth が読む代入前の Qsig で、実装の本体を取り出す。 -/
theorem ImplDecl.WellTyped.method_body {P : Program} {B : Builtins} {id : ImplDecl}
    (h : id.WellTyped P B) {cd : ClassDecl} {m : MethName} {ms : MethSig}
    (hc : P.classes id.cls = some cd) (hm : cd.methods m = some ms) :
    ∃ body, id.methods m = some body ∧ NamesWF ms.names ms.params ∧
      TelBodyTy P B StoreTy.empty (Qsig ms.params ms.ret ms.eff)
        (ms.tparams ++ TypeCtx.values id.tparams)
        (bindParams [] (id.dictTys.map (Ty.shift ms.tparams.length 0))) []
        (Tel.shiftV id.dictTys.length 0
          (Tel.bind (typeEnvAt ms.tparams.length [id.target] []) ms.tel)) body := by
  obtain ⟨cd', hc', _, _, _, _, hb, _⟩ := h
  have he : cd' = cd := Option.some.inj (hc'.symm.trans hc)
  subst cd'
  obtain ⟨body, hbody, hn, ht⟩ := hb m ms hm
  exact ⟨body, hbody, hn, by simpa only [ms.QTel_eq_Qsig hn] using ht⟩

/-- 変性と外部宣言の構造検証を、全 lookup の本体の型付けと同じ P に対して要求する。 -/
structure Program.WellTyped (P : Program) (B : Builtins) : Prop where
  variance : P.VarianceValid
  external : P.ExternalWF
  defs : ∀ f d, P.defs f = some d → Def.WellTyped P B d
  impls : ∀ i id, P.impls i = some id → ImplDecl.WellTyped P B id

end
end Benitoite.Release.Refinement
