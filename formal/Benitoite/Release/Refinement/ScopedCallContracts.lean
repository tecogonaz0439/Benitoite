import Benitoite.Release.Refinement.MembershipWiden
import Benitoite.Release.Refinement.ShapeTargets
import Benitoite.Release.Refinement.TelApplication
import Benitoite.Release.Refinement.CanonicalCells
import Benitoite.Release.Refinement.ComputationInputs

/-! # 具体化した同じ入力列と元の関数契約 -/
namespace Benitoite.Release.Refinement.ScopedCallContracts
open Benitoite.Release.Refinement

/-- 関数値の列から元の署名へ同じ実引数を戻し、一度選んだ範囲で対象を読む。 -/
theorem single_inputs {P B Ψ b sg ts es rs ws a e k p σ u}
    (admissible : PrimitiveAdmissible [] 0 sg Qempty ts es)
    (ranges : B.RangeAdmissible b sg rs)
    (signature : SignatureInstance P [] [] (Tel.instR rs sg.tel)
      (sg.tparams.map TParamDecl.kind) ts es)
    (relation : TelClosure P [] [] (instantiatedTel (Tel.instR rs sg.tel) ts es) u)
    (arguments : HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws u a e)
    (ground : ∀ w ∈ ws, w.Ground)
    (sh : B.ShapeOk b sg) (shape : sg.shape = .single k p)
    (names : NamesWF sg.names sg.params)
    (had : ∀ w ∈ ws, w.Adequate σ) :
    ∃ a₀ e₀ r t,
      HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws
        (instantiatedTel (Tel.instR rs sg.tel) ts es) a₀ e₀ ∧
      BuiltinArgs P B Ψ b sg (Ty.normTys ts) (es.map Eff.norm) rs ws a₀ e₀ ∧
      Ty.LeQ P [] [] a₀ a ∧ Eff.Covers [] [] e e₀ ∧ rs = [r] ∧
      (ws[p]?).bind Val.target? = some t ∧ r.Mem σ k t ∧
      sg.shapeAt ws = .single k p := by
  obtain ⟨a₀,e₀,original,le,covers⟩ := relation.apply
    (by intro i a h; cases h) signature.result arguments
  have args := BuiltinArgs.normalized admissible ranges signature original ground
  obtain ⟨r,t,hr,ht,hm,hs⟩ := sh.single_target shape names args had
  exact ⟨a₀,e₀,r,t,original,args,le,covers,hr,ht,hm,hs⟩

/-- 元の列へ戻した要求の内容・groundVal・端点を、同じ範囲で読む。 -/
theorem request_inputs {P B Ψ b sg ts es rs ws a e p σ u A}
    (admissible : PrimitiveAdmissible [] 0 sg Qempty ts es)
    (ranges : B.RangeAdmissible b sg rs)
    (signature : SignatureInstance P [] [] (Tel.instR rs sg.tel)
      (sg.tparams.map TParamDecl.kind) ts es)
    (relation : TelClosure P [] [] (instantiatedTel (Tel.instR rs sg.tel) ts es) u)
    (arguments : HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws u a e)
    (ground : ∀ w ∈ ws, w.Ground)
    (sh : B.ShapeOk b sg) (shape : sg.shape = .single .endpoint p)
    (names : NamesWF sg.names sg.params)
    (had : ∀ w ∈ ws, w.Adequate σ)
    (content : ∀ o, sg.params[p]? = some (.opaque o (.rvar 0)) → B.valContent o = some A) :
    ∃ a₀ e₀ r w target req,
      HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws
        (instantiatedTel (Tel.instR rs sg.tel) ts es) a₀ e₀ ∧
      Ty.LeQ P [] [] a₀ a ∧ Eff.Covers [] [] e e₀ ∧ rs = [r] ∧
      ws[p]? = some w ∧ sg.shapeAt ws = .single .endpoint p ∧
      (w = .checkedRequest target req ∨
        ∃ s snapshot, w = .checkedAt s snapshot target (some req)) ∧
      ModelHttp.valueRun [w] = .val req ∧ HasTypeV P B Ψ [] [] [] req A.norm ∧
      groundVal req = true ∧ req.reqTarget = some target ∧ r.Mem σ .endpoint target := by
  obtain ⟨a₀,e₀,r,t,original,args,le,covers,hr,_,_,_⟩ :=
    single_inputs admissible ranges signature relation arguments ground sh shape names had
  obtain ⟨r',w,target,req,hr',hw,hs,hreq⟩ := sh.single_request shape names args had content
  cases hr.symm.trans hr'
  exact ⟨a₀,e₀,r,w,target,req,original,le,covers,hr,hw,hs,hreq⟩

/-- 直接呼出しは、同じ元列への反射的な到達として接続する。 -/
example {P B Ψ b sg ts es rs ws a e k p σ}
    (args : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (sh : B.ShapeOk b sg) (shape : sg.shape = .single k p)
    (sc : PrimSig.Scoped P sg) (had : ∀ w ∈ ws, w.Adequate σ) :
    ∃ a₀ e₀ r t,
      HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws
        (instantiatedTel (Tel.instR rs sg.tel) ts es) a₀ e₀ ∧
      BuiltinArgs P B Ψ b sg (Ty.normTys ts) (es.map Eff.norm) rs ws a₀ e₀ ∧
      Ty.LeQ P [] [] a₀ a ∧ Eff.Covers [] [] e e₀ ∧ rs = [r] ∧
      (ws[p]?).bind Val.target? = some t ∧ r.Mem σ k t ∧ sg.shapeAt ws = .single k p :=
  single_inputs args.admissible args.ranges args.signature .refl args.arguments
    args.ground sh shape sc.namesWF had

/-- 要求の二経路にも、元の署名から同じ実引数列で到達する。 -/
example {P B Ψ b sg ts es rs ws a e p σ A}
    (args : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (sh : B.ShapeOk b sg) (shape : sg.shape = .single .endpoint p)
    (sc : PrimSig.Scoped P sg) (had : ∀ w ∈ ws, w.Adequate σ)
    (content : ∀ o, sg.params[p]? = some (.opaque o (.rvar 0)) → B.valContent o = some A) :
    ∃ a₀ e₀ r w target req,
      HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws
        (instantiatedTel (Tel.instR rs sg.tel) ts es) a₀ e₀ ∧
      Ty.LeQ P [] [] a₀ a ∧ Eff.Covers [] [] e e₀ ∧ rs = [r] ∧
      ws[p]? = some w ∧ sg.shapeAt ws = .single .endpoint p ∧
      (w = .checkedRequest target req ∨
        ∃ s snapshot, w = .checkedAt s snapshot target (some req)) ∧
      ModelHttp.valueRun [w] = .val req ∧ HasTypeV P B Ψ [] [] [] req A.norm ∧
      groundVal req = true ∧ req.reqTarget = some target ∧ r.Mem σ .endpoint target :=
  request_inputs args.admissible args.ranges args.signature .refl args.arguments args.ground
    sh shape sc.namesWF had content

/-- 比較不能な入力範囲の間には、scoped の部分型による拡大はない。 -/
example {P Γ Φ o k r s} (incomparable : ¬ s.Covers r) :
    ¬ Ty.LeQ P Γ Φ (.scoped o k (.fixed r)) (.scoped o k (.fixed s)) := by
  intro le
  obtain ⟨ix,ht,hc⟩ := le.holds (Or.inl rfl)
  rcases ht with ht | ht
  · have he : Ty.scoped o k (.fixed s) = .scoped o k ix := ht
    cases he
    exact incomparable hc
  · cases ht

/-- List の全要素を同じ範囲・同じ環境の対象読者へ渡す。 -/
example {P B Ψ Q vs T o k r σ}
    (values : HasTypeEachQ P B Ψ Q [] [] [] vs T)
    (ht : T.Holds o k (.fixed r)) (hk : B.valKind o = some k)
    (had : ∀ v ∈ vs, v.Adequate σ) :
    ∀ v ∈ vs, ∃ t, v.target? = some t ∧ r.Mem σ k t := by
  intro v hv
  exact (values.member hv).target_member ht hk (had v hv)

/-- ADT の実際の欄列の任意位置を、同じ値の対象読者へ渡す。 -/
example {P B Ψ Q vs as T o k r σ} {i : Nat}
    (values : HasTypeVsQ P B Ψ Q [] [] [] vs as) (field : as[i]? = some T)
    (ht : T.Holds o k (.fixed r)) (hk : B.valKind o = some k)
    (had : ∀ v ∈ vs, v.Adequate σ) :
    ∃ v t, vs[i]? = some v ∧ v.target? = some t ∧ r.Mem σ k t := by
  obtain ⟨v,hv,hvalue⟩ := values.get field
  obtain ⟨t,he,hm⟩ := hvalue.target_member ht hk (had v (List.mem_of_getElem? hv))
  exact ⟨v,t,hv,he,hm⟩

/-- Reference の実セルから得た同じ値と適格性を使う。 -/
example {P B σ Ψ μ l T o k r} (store : StoreOk P B σ Ψ μ)
    (location : Ψ l = some (.ref T)) (ht : T.Holds o k (.fixed r))
    (hk : B.valKind o = some k) :
    ∃ v t, μ l = some (.val v) ∧ v.target? = some t ∧ r.Mem σ k t := by
  obtain ⟨v,hv,typed,had⟩ := store.ref_cell location
  obtain ⟨t,he,hm⟩ := typed.target_member ((Ty.holds_norm ..).mpr ht) hk had
  exact ⟨v,t,hv,he,hm⟩

/-- Lazy は未評価の閉包を保持し、done の場合に同じ値の対象を読む。 -/
example {P B σ Ψ μ l T o k r} (store : StoreOk P B σ Ψ μ)
    (location : Ψ l = some (.lazy T)) (ht : T.Holds o k (.fixed r))
    (hk : B.valKind o = some k) :
    (∃ q, μ l = some (.thunk q) ∧
      ClosureTy P B (hideBuilders Ψ) [] none q T Eff.empty ∧ q.Adequate σ) ∨
    ∃ v t, μ l = some (.done v) ∧ v.target? = some t ∧ r.Mem σ k t := by
  rcases store.lazy_cell location with thunk | ⟨v,hv,typed,had⟩
  · exact Or.inl thunk
  · obtain ⟨t,he,hm⟩ := typed.target_member ht hk had
    exact Or.inr ⟨v,t,hv,he,hm⟩

/-- resume の直接・正規化した入力の両枝から、渡す同じ値の対象を読む。 -/
example {P B Ψ Q R Δ v T outEff l input result eff saved o k r σ}
    (typed : HasTypeCQ P B Ψ Q [] [] [] R (.resume (.loc l) v) T outEff Δ)
    (location : Ψ l = some (.cont input result eff saved))
    (ht : input.Holds o k (.fixed r)) (hk : B.valKind o = some k)
    (had : v.Adequate σ) :
    ∃ t, v.target? = some t ∧ r.Mem σ k t := by
  rcases typed.inv_resumeL rfl with ⟨b,t,e,hl,hv,_,_,_⟩ |
    ⟨R',b,t,e,hl,_,hv,_,_,_⟩
  · cases Option.some.inj (location.symm.trans hl)
    exact hv.target_member ht hk had
  · cases Option.some.inj (location.symm.trans hl)
    exact hv.target_member ((Ty.holds_norm ..).mpr ht) hk had

end Benitoite.Release.Refinement.ScopedCallContracts
