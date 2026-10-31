import Benitoite.Release.Refinement.NormalizedApplication
import Benitoite.Release.Refinement.TelTyping
import Benitoite.Release.Refinement.ExternalResponse
import Benitoite.Release.Refinement.Adequate

/-! # 組込み応答の型付き入力と保持値の適格性 -/
namespace Benitoite.Release.Refinement

structure BuiltinArgs (P : Program) (B : Builtins) (Ψ : StoreTy) (b : PrimName) (sg : PrimSig)
    (ts : List Ty) (es : List Eff) (rs : List RangeExpr) (ws : List Val) (a : Ty) (e : Eff) : Prop where
  admissible : PrimitiveAdmissible [] 0 sg Qempty ts es
  ranges : B.RangeAdmissible b sg rs
  signature : SignatureInstance P [] [] (Tel.instR rs sg.tel) (sg.tparams.map TParamDecl.kind) ts es
  arguments : HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws
    (instantiatedTel (Tel.instR rs sg.tel) ts es) a e
  ground : ∀ w ∈ ws, w.Ground
  types : ∀ t ∈ ts, t.WF 0 0 0 ∧ t.Canonical
  rows : ∀ e ∈ es, Eff.WF 0 0 0 e ∧ e.Canonical
  result : a.WF 0 0 0 ∧ a.Canonical
  effect : Eff.WF 0 0 0 e ∧ e.Canonical

/-- 終端の効果も、その注釈から範囲の整形式を取り出せる。 -/
theorem HasTypeTelArgsQ.effect_wf {P B Ψ Q C Γ Φ ws t a e}
    (h : HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t a e) : e.WF 0 C.length Γ.length := by
  match h with
  | .done ha => exact ha.wf.2.1
  | .param _ _ hs => exact hs.effect_wf

/-- 生の組込み値の導出から、遷移が読む正規化した引数の契約を作る。 -/
theorem BuiltinArgs.normalized {P B Ψ b sg ts es rs ws a e}
    (ha : PrimitiveAdmissible [] 0 sg Qempty ts es)
    (hr : B.RangeAdmissible b sg rs)
    (hs : SignatureInstance P [] [] (Tel.instR rs sg.tel) (sg.tparams.map TParamDecl.kind) ts es)
    (hw : HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws (instantiatedTel (Tel.instR rs sg.tel) ts es) a e)
    (hg : ∀ w ∈ ws, w.Ground) :
    BuiltinArgs P B Ψ b sg (Ty.normTys ts) (es.map Eff.norm) rs ws a e := by
  have hn := hw.normal (Tel.norm_idem _)
  refine ⟨ha.norm,hr,hs.norm_images,?_,hg,?_,?_,⟨hw.resultAnnotation.wf,hn.1⟩,⟨hw.effect_wf,hn.2⟩⟩
  · rw [instantiatedTel_norm_images]; exact hw
  · intro t ht
    obtain ⟨u,hu,rfl⟩ := List.mem_map.mp (by simpa only [Ty.normTys_eq_map] using ht)
    exact ⟨Ty.wf_norm (ha.typeScope u hu).1,Ty.norm_idem _⟩
  · intro e he
    obtain ⟨f,hf,rfl⟩ := List.mem_map.mp he
    exact ⟨Eff.wf_norm (ha.rowScope f hf),Eff.norm_idem _⟩

structure Builtins.ResponseAssumptions (P : Program) (B : Builtins) : Prop where
  delta_typed : ∀ Ψ b sg ts es rs ws a e,
    B.sig b = some sg → sg.kind = .pure → BuiltinArgs P B Ψ b sg ts es rs ws a e →
    ∃ out, B.delta b ts es rs ws = some out ∧ (∀ n, out ≠ .exit n) ∧
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out
  io_typed : ∀ Ψ b sg ts es rs ws a e out obs,
    B.sig b = some sg → (sg.kind = .io ∨ sg.kind = .exit) →
    BuiltinArgs P B Ψ b sg ts es rs ws a e → B.ioResponse b ts es ws out obs →
    Outcome.Typed P B Ψ out a ∧ AdequateResult ws out
  io_kind : ∀ Ψ b sg ts es rs ws a e out obs,
    B.sig b = some sg → BuiltinArgs P B Ψ b sg ts es rs ws a e →
    B.ioResponse b ts es ws out obs →
    (sg.kind = .io ∧ ∀ n, out ≠ .exit n) ∨ (sg.kind = .exit ∧ ∀ v, out ≠ .val v)
  io_exists : ∀ Ψ b sg ts es rs ws a e,
    B.sig b = some sg → (sg.kind = .io ∨ sg.kind = .exit) →
    BuiltinArgs P B Ψ b sg ts es rs ws a e →
    ∃ out obs, B.ioResponse b ts es ws out obs

def PrimSig.shapeAt (sg : PrimSig) (ws : List Val) : Scope.Signature.IOShape :=
  match sg.shape with
  | .single k p => if ((ws[p]?).bind Val.target?).isSome then .single k p else .topTargeted k
  | shape => shape

structure Builtins.TargetAgreement (P : Program) (B : Builtins) : Prop where
  io_target : ∀ Ψ b sg ts es rs ws a e out obs,
    B.sig b = some sg → (sg.kind = .io ∨ sg.kind = .exit) →
    BuiltinArgs P B Ψ b sg ts es rs ws a e → B.ioResponse b ts es ws out obs →
    Scope.Signature.ShapeTargets Val.target? (sg.shapeAt ws) ws obs

end Benitoite.Release.Refinement
