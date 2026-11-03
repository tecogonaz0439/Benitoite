import Benitoite.Release.Refinement.TelTyping
import Benitoite.Release.Refinement.Narrowing
import Benitoite.Release.Refinement.Context.Declarations
import Benitoite.Release.Refinement.DependentBeta

/-! # 反変の入力と同じ実引数による後続の具体化 -/
namespace Benitoite.Release.Refinement
noncomputable section

/-- 後続の導出を狭い入力の文脈へ移し、実引数を束縛する前の形を保つ。 -/
theorem TelBodyTy.narrow_input {P B Ψ Q C Γ Φ a b t body}
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF)
    (ha : Ty.Annotation P C Γ a) (hb : Ty.Annotation P C Γ b)
    (le : Ty.LeQ P Γ Φ b a)
    (typed : TelBodyTy P B Ψ Q C (Γ.extend a) (Φ.map Pred.lift) t body) :
    TelBodyTy P B Ψ Q C (Γ.extend b) (Φ.map Pred.lift) t body :=
  typed.narrow hA hw (.here le hb.wf ha.wf ha.sorted ha.declared)

/-- done の結果と効果を、渡した同じ値で同時に具体化する。 -/
theorem TelLe.open_done {P B Ψ Q C Γ Φ name a b r s e f v}
    (hΓ : Ctx.WF 0 C.length Γ)
    (ha : Ty.Annotation P C Γ a) (hb : Ty.Annotation P C Γ b)
    (hr : Ty.Annotation P C Γ (.dependentFn (.param name a (.done r e))))
    (hs : Ty.Annotation P C Γ (.dependentFn (.param name b (.done s f))))
    (le : Ty.LeQ P Γ Φ b a)
    (tail : TelLe P (Γ.extend b) (Φ.map Pred.lift) (.done r e) (.done s f))
    (hv : HasTypeVQ P B Ψ Q C Γ Φ v b) :
    HasTypeTelArgsQ P B Ψ Q C Γ Φ [v] (.param name a (.done r e))
      (substTyValues (openValue v) r) (substEffValues (openValue v) e) ∧
    HasTypeTelArgsQ P B Ψ Q C Γ Φ [v] (.param name b (.done s f))
      (substTyValues (openValue v) s) (substEffValues (openValue v) f) ∧
    Ty.LeQ P Γ Φ (substTyValues (openValue v) r) (substTyValues (openValue v) s) ∧
    Eff.Covers Γ Φ (substEffValues (openValue v) f) (substEffValues (openValue v) e) := by
  have va := hv.V_Sub le ha.wf ha.sorted ha.declared
  have transport := (SubstOk.openValue (R := none) hv hb hΓ).transport (by
    intro p hp
    obtain ⟨q,hq,rfl⟩ := List.mem_map.mp hp
    simpa only [Pred.openValue_lift] using
      (Entails.hyp (List.mem_append_right Γ.facts hq)))
  cases tail with
  | done result effect =>
    exact ⟨HasTypeTelArgsQ.one hr hΓ va, HasTypeTelArgsQ.one hs hΓ hv,
      result.bind _ transport, effect.bind _⟩

/-- 後続の引数の型が依存する、同じ最初の実値を開く。 -/
theorem TelLe.open_tail {P B Ψ Q C Γ Φ b t u v}
    (hΓ : Ctx.WF 0 C.length Γ) (hb : Ty.Annotation P C Γ b)
    (tail : TelLe P (Γ.extend b) (Φ.map Pred.lift) t u)
    (hv : HasTypeVQ P B Ψ Q C Γ Φ v b) :
    TelLe P Γ Φ (Tel.bind (Tel.argumentsEnv v) t) (Tel.bind (Tel.argumentsEnv v) u) := by
  have transport := (SubstOk.openValue (R := none) hv hb hΓ).transport (by
    intro p hp
    obtain ⟨q,hq,rfl⟩ := List.mem_map.mp hp
    simpa only [Pred.openValue_lift] using
      (Entails.hyp (List.mem_append_right Γ.facts hq)))
  simpa only [Tel.argumentsEnv,valEnv_openValue] using
    tail.bind (valEnv (openValue v)) transport

/-- 二番目の型・結果・効果を、順序を保った同じ二実値で具体化する。 -/
theorem TelLe.open_two {P B Ψ Q C Γ Φ n m a b c d r s e f v w}
    (hΓ : Ctx.WF 0 C.length Γ)
    (source : Ty.Annotation P C Γ (.dependentFn (.param n a (.param m c (.done r e)))))
    (target : Ty.Annotation P C Γ (.dependentFn (.param n b (.param m d (.done s f)))))
    (le : Ty.LeQ P Γ Φ b a)
    (tail : TelLe P (Γ.extend b) (Φ.map Pred.lift) (.param m c (.done r e)) (.param m d (.done s f)))
    (hv : HasTypeVQ P B Ψ Q C Γ Φ v b)
    (hw : HasTypeVQ P B Ψ Q C Γ Φ w (d.bind (Tel.argumentsEnv v))) :
    ∃ r' s' e' f',
      HasTypeTelArgsQ P B Ψ Q C Γ Φ [v,w] (.param n a (.param m c (.done r e))) r' e' ∧
      HasTypeTelArgsQ P B Ψ Q C Γ Φ [v,w] (.param n b (.param m d (.done s f))) s' f' ∧
      Ty.LeQ P Γ Φ r' s' ∧ Eff.Covers Γ Φ f' e' := by
  have ha : Ty.Annotation P C Γ a := ⟨source.wf.1,source.sorted.1,source.declared.1⟩
  have hb : Ty.Annotation P C Γ b := ⟨target.wf.1,target.sorted.1,target.declared.1⟩
  have va := hv.V_Sub le ha.wf ha.sorted ha.declared
  have sa := Tel.annotation_open hΓ source va
  have ta := Tel.annotation_open hΓ target hv
  have opened := TelLe.open_tail hΓ hb tail hv
  rw [Tel.bind_param,Tel.bind_done] at sa ta opened
  cases opened with
  | param second rest =>
    have h := TelLe.open_done hΓ ⟨sa.wf.1,sa.sorted.1,sa.declared.1⟩
      ⟨ta.wf.1,ta.sorted.1,ta.declared.1⟩ sa ta second rest hw
    exact ⟨_,_,_,_,.param ha va h.1,.param hb hv h.2.1,h.2.2.1,h.2.2.2⟩

/-- 二段の関係は、元の依存列と到達列の間に同じ順序で残る。 -/
theorem TelClosure.two_steps {P Γ Φ t u v}
    (first : TelLe P Γ Φ t u) (second : TelLe P Γ Φ u v) :
    TelClosure P Γ Φ t v := .tail (.tail .refl first) second

/-- 通常の関数の view と依存列の正規形を同じ到達関係へ通す。 -/
theorem TelClosure.from_function_norm {P Γ Φ ns ps r e u}
    (same : (Ty.toTel ns ps r e).norm = u.norm) :
    TelClosure P Γ Φ (Ty.toTel ns ps r e) u := .tail .refl (.of_norm_eq same)

namespace TelApplicationExamples
private def argument (strong : Bool) : Ty :=
  if strong then .refined (.base .integer) .truth else .base .integer
private def result : Ty := .refined (.base .integer) (.eq (.var 0) (.var 1))
private def contract (strong : Bool) : Tel := .param "x" (argument strong) (.done result Eff.empty)

private theorem argument_annotation (P : Program) (strong : Bool) :
    Ty.Annotation P [] [] (argument strong) := by
  cases strong
  · exact ⟨trivial,trivial,trivial⟩
  · exact ⟨⟨trivial,trivial,by intro b t e h; cases h⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩

private theorem contract_annotation (P : Program) (strong : Bool) :
    Ty.Annotation P [] [] (.dependentFn (contract strong)) := by
  constructor
  · cases strong <;> simp [contract, argument, result, Ty.WF, Tel.WF, Pred.WF,
      Pred.VarsIn, Term.VarsIn, Ty.NotContCore, Ty.core, Eff.WF, Ty.WFList,
      Eff.Canonical, Eff.empty, Eff.norm, Ty.normTys]
  · cases strong <;> simp [contract, argument, result, Ty.Sorted, Tel.Sorted,
      Pred.Sorted, Term.HasSort, Term.References, Term.VarsIn, Term.Shape,
      Ctx.Readable, Ctx.extend, Ty.HasSort, Ty.sort?, Ty.core, sortedEff, sortedTys,
      Ty.shiftV, Eff.empty]
  · cases strong <;> simp [contract, argument, result, Ty.Declared, Tel.Declared,
      Pred.Declared, Term.Declared, declaredEff, declaredTys, Eff.empty, Ctx.declarationSelf,
      Ctx.extend, Ctx.Readable, Ty.core, Ty.shiftV, predBind]

private theorem input_le (P : Program) : Ty.LeQ P [] [] (argument true) (argument false) := .forget

/-- 反変の一引数で、同じ7を依存結果と効果の両方へ束縛する。 -/
example (P : Program) (B : Builtins) (Ψ : StoreTy) (Q : NoFailCtx) :
    ∃ r e, HasTypeTelArgsQ P B Ψ Q [] [] [] [.const (.integer ⟨7,by decide⟩)]
      (contract false) r e ∧ Ty.LeQ P [] [] r r ∧ Eff.Covers [] [] e e := by
  have hv : HasTypeVQ P B Ψ Q [] [] [] (.const (.integer ⟨7,by decide⟩)) (argument true) :=
    .V_Sub (.V_Const trivial) (.introduce trivial .truth)
      (argument_annotation P true).wf (argument_annotation P true).sorted (argument_annotation P true).declared
  have h := TelLe.open_done (name := "x") (by intro i a h; cases h)
    (argument_annotation P false) (argument_annotation P true)
    (contract_annotation P false) (contract_annotation P true) (input_le P)
    (.done .refl (Eff.Covers.refl _ _ _)) hv
  exact ⟨_,_,h.1,h.2.2.1,h.2.2.2⟩

/-- 狭い入力の変数を読む同じ本体を、既存narrowingへ通す。 -/
example {P B Ψ Q} (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF) :
    TelBodyTy P B Ψ Q [] (Ctx.extend [] (argument true)) []
      (.done (.base .integer) Eff.empty) (.ret (.var 0)) := by
  exact TelBodyTy.narrow_input hA hw (argument_annotation P false) (argument_annotation P true)
    (input_le P) (.done (.C_Return (.V_Var rfl (by intro b t e h; cases h))))

/-- 二段のtailを、依存する同じ後続のまま合成する。 -/
example (P : Program) : TelClosure P [] [] (contract false) (contract true) :=
  TelClosure.two_steps (.param (input_le P) (.done .refl (Eff.Covers.refl _ _ _)))
    (.param .refl (.done .refl (Eff.Covers.refl _ _ _)))

private def twoContract (strong : Bool) : Tel :=
  .param "x" (argument strong) (.param "y" result (.done (.base .unit) Eff.empty))

private theorem two_annotation (P : Program) (strong : Bool) :
    Ty.Annotation P [] [] (.dependentFn (twoContract strong)) := by
  constructor
  · cases strong <;> simp [twoContract,argument,result,Ty.WF,Tel.WF,Pred.WF,
      Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,Eff.WF,Ty.WFList,
      Eff.Canonical,Eff.empty,Eff.norm,Ty.normTys]
  · cases strong <;> simp [twoContract,argument,result,Ty.Sorted,Tel.Sorted,
      Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,
      Ctx.Readable,Ctx.extend,Ty.HasSort,Ty.sort?,Ty.core,sortedEff,sortedTys,
      Ty.shiftV,Eff.empty]
  · cases strong <;> simp [twoContract,argument,result,Ty.Declared,Tel.Declared,
      Pred.Declared,Term.Declared,declaredEff,declaredTys,Eff.empty,Ctx.declarationSelf,
      Ctx.extend,Ctx.Readable,Ty.core,Ty.shiftV,predBind]

/-- yの型はxとの等号を持ち、同じ7を二番目の型にも反映する。 -/
example (P : Program) (B : Builtins) (Ψ : StoreTy) (Q : NoFailCtx) :
    ∃ r s e f, HasTypeTelArgsQ P B Ψ Q [] [] []
      [.const (.integer ⟨7,by decide⟩),.const (.integer ⟨7,by decide⟩)] (twoContract false) r e ∧
      HasTypeTelArgsQ P B Ψ Q [] [] []
      [.const (.integer ⟨7,by decide⟩),.const (.integer ⟨7,by decide⟩)] (twoContract true) s f ∧
      Ty.LeQ P [] [] r s ∧ Eff.Covers [] [] f e := by
  have hv : HasTypeVQ P B Ψ Q [] [] [] (.const (.integer ⟨7,by decide⟩)) (argument true) :=
    .V_Sub (.V_Const trivial) (.introduce trivial .truth)
      (argument_annotation P true).wf (argument_annotation P true).sorted (argument_annotation P true).declared
  have hw : HasTypeVQ P B Ψ Q [] [] [] (.const (.integer ⟨7,by decide⟩))
      (result.bind (Tel.argumentsEnv (.const (.integer ⟨7,by decide⟩)))) := by
    change HasTypeVQ P B Ψ Q [] [] [] (.const (.integer ⟨7,by decide⟩))
      (.refined (.base .integer) (.eq (.var 0) (.integer 7)))
    refine .V_Refine (.V_Const trivial) rfl rfl ?_ ?_ Entails.eq_refl trivial ?_
    · exact ⟨⟨⟨_,rfl,by intro b t e h; cases h⟩,⟨_,rfl,rfl⟩⟩,⟨trivial,rfl⟩⟩
    · simp [Pred.WF,Pred.VarsIn,Term.VarsIn]
    · exact ⟨⟨_,rfl,by intro b t e h; cases h⟩,trivial⟩
  exact TelLe.open_two (by intro i a h; cases h) (two_annotation P false)
    (two_annotation P true) (input_le P)
    (.param .refl (.done .refl (Eff.Covers.refl _ _ _))) hv hw

/-- 通常の関数のviewと正規化した依存列を対応させる。 -/
example (P : Program) :
    TelClosure P [] [] (Ty.toTel ["x"] [.base .integer] (.base .unit) Eff.empty)
      (Tel.norm (Ty.toTel ["x"] [.base .integer] (.base .unit) Eff.empty)) :=
  TelClosure.from_function_norm (Tel.norm_idem _).symm

end TelApplicationExamples

end
end Benitoite.Release.Refinement
