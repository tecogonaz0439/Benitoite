import Lean
import Benitoite
namespace L50CContracts
open Benitoite.Release.Refinement
example : ∀ {P B Ψ Q v T o k r σ},
    HasTypeVQ P B Ψ Q [] [] [] v T → T.Holds o k (.fixed r) →
    B.valKind o = some k → v.Adequate σ →
    ∃ t, v.target? = some t ∧ r.Mem σ k t := @HasTypeVQ.target_member
example : ∀ {P B Ψ b sg ts es rs ws a e k p σ},
    B.ShapeOk b sg → sg.shape = .single k p → NamesWF sg.names sg.params →
    BuiltinArgs P B Ψ b sg ts es rs ws a e → (∀ w ∈ ws, w.Adequate σ) →
    ∃ r t, rs = [r] ∧ (ws[p]?).bind Val.target? = some t ∧
      r.Mem σ k t ∧ sg.shapeAt ws = .single k p := @Builtins.ShapeOk.single_target
example : ∀ {P B Ψ Q C Γ Φ t u ws a e},
    Ctx.WF 0 C.length Γ → Ty.Annotation P C Γ (.dependentFn t) →
    TelClosure P Γ Φ t u → HasTypeTelArgsQ P B Ψ Q C Γ Φ ws u a e →
    ∃ b f, HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t b f ∧
      Ty.LeQ P Γ Φ b a ∧ Eff.Covers Γ Φ e f := @TelClosure.apply
-- 要求の保持形を既知とする呼出しでも、存在量化した新しい入口を適用できる。
example {P B Ψ Q v T o r σ req target A}
    (hv : HasTypeVQ P B Ψ Q [] [] [] v T)
    (ht : T.Holds o .endpoint (.fixed r)) (hk : B.valKind o = some .endpoint)
    (hc : B.valContent o = some A) (ha : v.Adequate σ)
    (form : v = .checkedRequest target req ∨
      ∃ s snapshot, v = .checkedAt s snapshot target (some req)) :
    ModelHttp.valueRun [v] = .val req ∧ HasTypeV P B Ψ [] [] [] req A.norm ∧
      groundVal req = true ∧ req.reqTarget = some target ∧ r.Mem σ .endpoint target := by
  obtain ⟨target',req',found,proof⟩ := hv.request_target ht hk hc ha
  rcases form with rfl | ⟨s,snapshot,rfl⟩ <;>
    rcases found with h | ⟨s',snapshot',h⟩ <;> cases h
  all_goals exact proof

example {P B Ψ b sg ts es rs ws a e p σ A req target}
    (sh : B.ShapeOk b sg) (hs : sg.shape = .single .endpoint p)
    (names : NamesWF sg.names sg.params)
    (args : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (had : ∀ w ∈ ws, w.Adequate σ)
    (content : ∀ o, sg.params[p]? = some (.opaque o (.rvar 0)) → B.valContent o = some A)
    (form : ∀ w, ws[p]? = some w → w = .checkedRequest target req ∨
      ∃ s snapshot, w = .checkedAt s snapshot target (some req)) :
    ∃ r w, rs = [r] ∧ ws[p]? = some w ∧ sg.shapeAt ws = .single .endpoint p ∧
      ModelHttp.valueRun [w] = .val req ∧ HasTypeV P B Ψ [] [] [] req A.norm ∧
      groundVal req = true ∧ req.reqTarget = some target ∧ r.Mem σ .endpoint target := by
  obtain ⟨r,w,target',req',hr,hw,hs,found,proof⟩ :=
    sh.single_request hs names args had content
  refine ⟨r,w,hr,hw,hs,?_⟩
  rcases form w hw with rfl | ⟨s,snapshot,rfl⟩ <;>
    rcases found with h | ⟨s',snapshot',h⟩ <;> cases h
  all_goals exact proof

example {P B Ψ b sg ts es rs ws a e p σ u A req target}
    (admissible : PrimitiveAdmissible [] 0 sg Benitoite.Release.Qempty ts es)
    (ranges : B.RangeAdmissible b sg rs)
    (signature : SignatureInstance P [] [] (Tel.instR rs sg.tel)
      (sg.tparams.map TParamDecl.kind) ts es)
    (relation : TelClosure P [] [] (instantiatedTel (Tel.instR rs sg.tel) ts es) u)
    (arguments : HasTypeTelArgsQ P B Ψ Benitoite.Release.Qempty [] [] [] ws u a e)
    (ground : ∀ w ∈ ws, w.Ground)
    (sh : B.ShapeOk b sg) (shape : sg.shape = .single .endpoint p)
    (names : NamesWF sg.names sg.params) (had : ∀ w ∈ ws, w.Adequate σ)
    (content : ∀ o, sg.params[p]? = some (.opaque o (.rvar 0)) → B.valContent o = some A)
    (form : ∀ w, ws[p]? = some w → w = .checkedRequest target req ∨
      ∃ s snapshot, w = .checkedAt s snapshot target (some req)) :
    ∃ a₀ e₀ r w,
      HasTypeTelArgsQ P B Ψ Benitoite.Release.Qempty [] [] [] ws
        (instantiatedTel (Tel.instR rs sg.tel) ts es) a₀ e₀ ∧
      Ty.LeQ P [] [] a₀ a ∧ Eff.Covers [] [] e e₀ ∧ rs = [r] ∧
      ws[p]? = some w ∧ sg.shapeAt ws = .single .endpoint p ∧
      ModelHttp.valueRun [w] = .val req ∧ HasTypeV P B Ψ [] [] [] req A.norm ∧
      groundVal req = true ∧ req.reqTarget = some target ∧ r.Mem σ .endpoint target := by
  obtain ⟨a₀,e₀,r,w,target',req',original,le,covers,hr,hw,hs,found,proof⟩ :=
    ScopedCallContracts.request_inputs admissible ranges signature relation arguments ground
      sh shape names had content
  refine ⟨a₀,e₀,r,w,original,le,covers,hr,hw,hs,?_⟩
  rcases form w hw with rfl | ⟨s,snapshot,rfl⟩ <;>
    rcases found with h | ⟨s',snapshot',h⟩ <;> cases h
  all_goals exact proof
end L50CContracts
