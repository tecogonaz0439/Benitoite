import Benitoite.Release.Refinement.MembershipTargets
import Benitoite.Release.Refinement.BuiltinResponse
import Benitoite.Release.Refinement.PrimitiveScoped

/-! # 依存する実引数列の任意位置と単一の保持対象 -/
namespace Benitoite.Release.Refinement

private inductive OpaqueAt : Tel → Nat → OpaqueName → RangeIx → Prop where
  | head : OpaqueAt (.param n (.opaque o ix) rest) 0 o ix
  | tail : OpaqueAt rest p o ix → OpaqueAt (.param n a rest) (p+1) o ix

private theorem OpaqueAt.norm {tel p o ix} (h : OpaqueAt tel p o ix) :
    OpaqueAt tel.norm p o ix := by
  match h with
  | .head => exact .head
  | .tail h => exact .tail h.norm

private theorem OpaqueAt.bind {tel p o ix} (h : OpaqueAt tel p o ix) (θ : SubstEnv) :
    OpaqueAt (Tel.bind θ tel) p o (ix.inst θ.ranges) := by
  unfold Tel.bind
  apply OpaqueAt.norm
  induction h generalizing θ with
  | head => exact .head
  | tail h ih => exact .tail (ih θ.up)

private theorem OpaqueAt.signature {ns ps ret eff p o ix}
    (hn : NamesWF ns ps) (hp : ps[p]? = some (.opaque o ix)) :
    OpaqueAt (signatureTel ns ps ret eff) p o ix := by
  induction ns generalizing ps p with
  | nil => cases ps <;> simp_all [NamesWF]
  | cons n ns ih =>
    cases ps with
    | nil => simp at hp
    | cons a ps =>
      cases p with
      | zero => simp at hp; subst a; exact .head
      | succ p =>
        exact .tail (ih ⟨by simpa using hn.1, hn.2.of_cons⟩ hp)

private theorem OpaqueAt.argument {P B Ψ Q C Γ Φ ws tel a e p o r}
    (h : HasTypeTelArgsQ P B Ψ Q C Γ Φ ws tel a e)
    (hp : OpaqueAt tel p o (.fixed r)) :
    ∃ w, ws[p]? = some w ∧ HasTypeVQ P B Ψ Q C Γ Φ w (.opaque o (.fixed r)) := by
  induction ws generalizing tel p with
  | nil => cases h; cases hp
  | cons v vs ih =>
    cases h with
    | param ha hv hs =>
      cases hp with
      | head => exact ⟨_, rfl, hv⟩
      | tail hp =>
        obtain ⟨w,hw,ht⟩ := ih hs (hp.bind (Tel.argumentsEnv _))
        exact ⟨w, hw, ht⟩

/-- 宣言の形成から名前と引数型の同数・非重複を取り出す。 -/
theorem PrimSig.Scoped.namesWF {P sg} (h : PrimSig.Scoped P sg) : NamesWF sg.names sg.params :=
  h.names

/-- 全ての形で、同じ効果名と操作表の所属を返す。 -/
theorem Builtins.ShapeOk.common {B : Builtins} {b : PrimName} {sg : PrimSig} (h : B.ShapeOk b sg) :
    ∃ l bs, sg.opEff = some l ∧ sg.neffs = 0 ∧ B.effects l = some bs ∧ b ∈ bs := by
  obtain ⟨l,bs,ho,hn,he,hb,_⟩ := h
  exact ⟨l,bs,ho,hn,he,hb⟩

/-- 原署名の効果は、Top 又は範囲変数0の名前付き原子一つである。 -/
theorem Builtins.ShapeOk.eff_eq {B : Builtins} {b : PrimName} {sg : PrimSig} (h : B.ShapeOk b sg) :
    ∃ (l : EffName) (bs : List PrimName) (ix : RangeIx), sg.opEff = some l ∧ B.effects l = some bs ∧ b ∈ bs ∧
      sg.eff = .mk (fun a => decide (a = .name l ix)) [] := by
  obtain ⟨l,bs,ho,_,he,hb,sh⟩ := h
  cases hs : sg.shape with
  | untargeted =>
    rw [hs] at sh
    exact ⟨l,bs,.top,ho,he,hb,sh.2.2⟩
  | topTargeted k =>
    rw [hs] at sh
    exact ⟨l,bs,.top,ho,he,hb,sh.2.2⟩
  | single k p =>
    rw [hs] at sh
    exact ⟨l,bs,.rvar 0,ho,he,hb,sh.2.2.1⟩

/-- 範囲列の全入力で、原署名の同じ効果原子を具体化する。 -/
theorem Builtins.ShapeOk.inst_eff_mem {B : Builtins} {b : PrimName} {sg : PrimSig}
    (h : B.ShapeOk b sg) (rs : List RangeExpr) :
    ∃ (l : EffName) (bs : List PrimName) (ix : RangeIx), sg.opEff = some l ∧ B.effects l = some bs ∧ b ∈ bs ∧
      (Eff.instR rs sg.eff).mem (.name l (ix.inst rs)) := by
  obtain ⟨l,bs,ix,ho,he,hb,hf⟩ := h.eff_eq
  refine ⟨l,bs,ix,ho,he,hb,?_⟩
  rw [Eff.instR_eq_bind]
  simp only [Eff.bind,Eff.mem_norm]
  apply (Eff.mem_rawBind _ _ _).mpr
  exact Or.inl ⟨.name l ix,by simp [hf,Eff.mem,Eff.test,Eff.atoms],rfl,trivial⟩

/-- single の原署名は対象位置に opaque と同じ範囲変数を持つ。 -/
theorem Builtins.ShapeOk.single {B : Builtins} {b : PrimName} {sg : PrimSig} {k p} (h : B.ShapeOk b sg)
    (hs : sg.shape = .single k p) :
    ∃ l o, sg.opEff = some l ∧ B.effKind l = some k ∧ sg.rkinds = [k] ∧
      sg.eff = .mk (fun a => decide (a = .name l (.rvar 0))) [] ∧
      sg.params[p]? = some (.opaque o (.rvar 0)) ∧ B.valKind o = some k := by
  obtain ⟨l,_,ho,_,_,_,sh⟩ := h
  rw [hs] at sh
  obtain ⟨hk,hr,he,o,hp,hv⟩ := sh
  exact ⟨l,o,ho,hk,hr,he,hp,hv⟩

/-- 一回の範囲具体化で、対象位置と効果の原子が同じ範囲を指す。 -/
theorem Builtins.ShapeOk.single_inst {B : Builtins} {b : PrimName} {sg : PrimSig} {k p} (h : B.ShapeOk b sg)
    (hs : sg.shape = .single k p) (r : RangeExpr) :
    ∃ l o, sg.opEff = some l ∧ B.effKind l = some k ∧
      (Eff.instR [r] sg.eff).mem (.name l (.fixed r)) ∧
      (sg.params.map (Ty.instR [r]))[p]? = some (.opaque o (.fixed r)) ∧
      B.valKind o = some k := by
  obtain ⟨l,o,ho,hk,_,he,hp,hv⟩ := h.single hs
  refine ⟨l,o,ho,hk,?_,?_,hv⟩
  · rw [Eff.instR_eq_bind]
    simp only [Eff.bind,Eff.mem_norm]
    exact (Eff.mem_rawBind _ _ _).mpr
      (Or.inl ⟨.name l (.rvar 0),by simp [he,Eff.mem,Eff.test,Eff.atoms],rfl,trivial⟩)
  · simp [List.getElem?_map,hp,Ty.instR,Ty.substRAt,Ty.mapRanges,Ty.rawMapRanges,
      Ty.norm,rangeAt,mapIx]

private theorem single_input {P B Ψ b ts es rs ws a e} {sg : PrimSig}
    {k : Scope.Domain.Kind} {p : Nat} {o : OpaqueName}
    (names : NamesWF sg.names sg.params)
    (args : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (hr : sg.rkinds = [k]) (hp : sg.params[p]? = some (.opaque o (.rvar 0))) :
    ∃ r w, rs = [r] ∧ ws[p]? = some w ∧
      HasTypeVQ P B Ψ Qempty [] [] [] w (.opaque o (.fixed r)) := by
  have count := args.ranges.1
  rw [hr] at count
  obtain ⟨r,rfl⟩ : ∃ r, rs = [r] := by
    cases rs with
    | nil => simp at count
    | cons r rest =>
      cases rest with
      | nil => exact ⟨r,rfl⟩
      | cons _ _ => simp at count
  have atSig : OpaqueAt sg.tel p o (.rvar 0) := OpaqueAt.signature names hp
  have atRange : OpaqueAt (Tel.instR [r] sg.tel) p o (.fixed r) := by
    rw [Tel.instR_eq_bind]
    exact atSig.bind (.rangesOnly [r])
  have atType : OpaqueAt (instantiatedTel (Tel.instR [r] sg.tel) ts es) p o (.fixed r) :=
    atRange.bind (typeEnvAt 0 ts es)
  obtain ⟨w,hw,ht⟩ := OpaqueAt.argument args.arguments atType
  exact ⟨r,w,rfl,hw,ht⟩

theorem Builtins.ShapeOk.single_target {P B Ψ b sg ts es rs ws a e k p σ}
    (sh : B.ShapeOk b sg) (single : sg.shape = .single k p)
    (names : NamesWF sg.names sg.params)
    (args : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (had : ∀ w ∈ ws, w.Adequate σ) :
    ∃ r t, rs = [r] ∧ (ws[p]?).bind Val.target? = some t ∧
      r.Mem σ k t ∧ sg.shapeAt ws = .single k p := by
  obtain ⟨l,bs,ho,hn,he,hb,hs⟩ := sh
  rw [single] at hs
  obtain ⟨hk,hr,hef,o,hp,hv⟩ := hs
  obtain ⟨r,w,rfl,hw,ht⟩ := single_input names args hr hp
  obtain ⟨t,ht,hm⟩ := ht.target_member (Or.inr rfl) hv
    (had w (List.mem_of_getElem? hw))
  refine ⟨r,t,rfl,?_,hm,?_⟩
  · simp [hw,ht]
  · simp [PrimSig.shapeAt, single, hw, ht]

/-- 実際の対象位置にある要求を、同じ内容型・groundVal・endpointへ渡す。 -/
theorem Builtins.ShapeOk.single_request {P B Ψ b sg ts es rs ws a e p σ A}
    (sh : B.ShapeOk b sg) (hs : sg.shape = .single .endpoint p)
    (names : NamesWF sg.names sg.params)
    (args : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (had : ∀ w ∈ ws, w.Adequate σ)
    (content : ∀ o, sg.params[p]? = some (.opaque o (.rvar 0)) → B.valContent o = some A) :
    ∃ r w target req, rs = [r] ∧ ws[p]? = some w ∧ sg.shapeAt ws = .single .endpoint p ∧
      (w = .checkedRequest target req ∨
        ∃ s snapshot, w = .checkedAt s snapshot target (some req)) ∧
      ModelHttp.valueRun [w] = .val req ∧ HasTypeV P B Ψ [] [] [] req A.norm ∧
      groundVal req = true ∧ req.reqTarget = some target ∧ r.Mem σ .endpoint target := by
  obtain ⟨_,o,_,_,hr,_,hp,hk⟩ := sh.single hs
  obtain ⟨r,w,hrr,hw,ht⟩ := single_input names args hr hp
  obtain ⟨target,req,hreq⟩ := ht.request_target (Or.inr rfl) hk (content o hp)
    (had w (List.mem_of_getElem? hw))
  obtain ⟨r',_,hrr',_,_,shape⟩ := sh.single_target hs names args had
  cases hrr.symm.trans hrr'
  exact ⟨r,w,target,req,hrr,hw,shape,hreq⟩

/-- 共通条件と原署名の効果原子は、範囲列の長さを問わず対応する。 -/
example {B : Builtins} {b : PrimName} {sg : PrimSig} (h : B.ShapeOk b sg)
    (rs : List RangeExpr) :
    sg.neffs = 0 ∧ ∃ (l : EffName) (bs : List PrimName) (ix : RangeIx),
      sg.opEff = some l ∧ B.effects l = some bs ∧ b ∈ bs ∧
      (Eff.instR rs sg.eff).mem (.name l (ix.inst rs)) := by
  obtain ⟨_,_,_,hn,_,_⟩ := h.common
  exact ⟨hn,h.inst_eff_mem rs⟩

/-- 要求の二導入経路を任意の対象位置で同じ射影へ接続する。 -/
example {P B Ψ b sg ts es rs ws a e p σ A}
    (sh : B.ShapeOk b sg) (hs : sg.shape = .single .endpoint p)
    (sc : PrimSig.Scoped P sg) (args : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (had : ∀ w ∈ ws, w.Adequate σ)
    (content : ∀ o, sg.params[p]? = some (.opaque o (.rvar 0)) → B.valContent o = some A) :
    ∃ r w target req, rs = [r] ∧ ws[p]? = some w ∧ sg.shapeAt ws = .single .endpoint p ∧
      (w = .checkedRequest target req ∨
        ∃ s snapshot, w = .checkedAt s snapshot target (some req)) ∧
      ModelHttp.valueRun [w] = .val req ∧ HasTypeV P B Ψ [] [] [] req A.norm ∧
      groundVal req = true ∧ req.reqTarget = some target ∧ r.Mem σ .endpoint target :=
  sh.single_request hs sc.namesWF args had content

/-- 整形式の表の names 欄を、同じ型付き呼出しへ供給する。 -/
example {P B Ψ b sg ts es rs ws a e k p σ}
    (hsc : PrimSig.Scoped P sg) (sh : B.ShapeOk b sg)
    (single : sg.shape = .single k p)
    (args : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (had : ∀ w ∈ ws, w.Adequate σ) :
    ∃ r t, rs = [r] ∧ (ws[p]?).bind Val.target? = some t ∧
      r.Mem σ k t ∧ sg.shapeAt ws = .single k p :=
  sh.single_target single hsc.namesWF args had

namespace SingleTargetExamples
noncomputable section

private def range : RangeExpr := .path (.tree ["data"])
private def target : Scope.Domain.Target := .path ["data","a"]
private def result : Ty := .data "Result" [.base .string,.opaque "IOError" .top]
private def effect : Eff := .mk (fun a => decide (a = .name "File.Read" (.fixed range))) []
private def signature : PrimSig where
  tparams := []
  neffs := 0
  names := ["path"]
  params := [.opaque "Scope.PathIn" (.rvar 0)]
  ret := result
  eff := .mk (fun a => decide (a = .name "File.Read" (.rvar 0))) []
  admits := fun _ ts => ts = []
  kind := .io
  opEff := some "File.Read"
  rkinds := [.path]
  shape := .single .path 0

private def builtins : Builtins where
  sig := fun b => if b = "File.readTextIn" then some signature else none
  delta := fun _ _ _ _ _ => none
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => False
  isResource := fun _ => false
  effects := fun l => if l = "File.Read" then some ["File.readTextIn"] else none
  sat := fun _ _ _ => False
  refGet := "Reference.get"
  refSet := "Reference.set"
  effKind := fun l => if l = "File.Read" then some .path else none
  valKind := fun o => if o = "Scope.PathIn" then some .path else none
  admitsR := fun b rs => b = "File.readTextIn" ∧ rs = [range]

private def program : Program where
  defs := fun _ => none
  cons := fun c => if c = "Result.Ok" then some ⟨"Result",2,[.tvar 0]⟩
    else if c = "Result.Error" then some ⟨"Result",2,[.tvar 1]⟩ else none
  ops := fun _ => none
  effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none

private theorem result_arity : program.DataArity "Result" 2 := by
  constructor
  · exact ⟨"Result.Ok",⟨"Result",2,[.tvar 0]⟩,by simp [program],rfl⟩
  · intro c cd hc _
    simp only [program] at hc
    split at hc
    · cases hc; rfl
    · split at hc
      · cases hc; rfl
      · cases hc

private theorem shape : builtins.ShapeOk "File.readTextIn" signature := by
  exact ⟨"File.Read",["File.readTextIn"],rfl,rfl,rfl,by simp,
    rfl,rfl,rfl,"Scope.PathIn",rfl,rfl⟩

private theorem instantiated : instantiatedTel (Tel.instR [range] signature.tel) [] [] =
    .param "path" (.opaque "Scope.PathIn" (.fixed range)) (.done result effect) := by
  have atoms : mapRangeAtoms (rangeAt 0 [range])
      (fun a => decide (a = .name "File.Read" (.rvar 0))) =
      (fun a => decide (a = .name "File.Read" (.fixed range))) := by
    funext a
    simp [mapRangeAtoms,mapAtomRanges,mapIx,rangeAt,eq_comm]
  simp [signature,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,
    Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,atoms,
    Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
    Eff.norm,typeEnvAt,substAtoms_nil,instAtoms_nil,rowFails,result,effect,
    RangeIx.inst,SubstEnv.up]

private theorem result_annotation (Γ : Ctx) : Ty.Annotation program [] Γ result := by
  exact ⟨by trivial,by trivial,⟨⟨2,result_arity,rfl⟩,by trivial⟩⟩

private theorem arguments (Ψ : StoreTy) : BuiltinArgs program builtins Ψ "File.readTextIn"
    signature [] [] [range] [.checked target] result effect := by
  constructor
  · constructor
    · rfl
    · rfl
    · simp
    · rfl
    · simp
    · simp [signature,Eff.RowsIn,Ty.RowsInList]
    · intro i h; simp [Qsig,signature,result,QTys,QTy,QEff,Benitoite.Release.Qempty] at h
    · intro i h; simp [Qsig,signature,result,QTys,QTy,QEff,Benitoite.Release.Qempty] at h
    · simp [signature,PrimSig.tel,signatureTel,Tel.RowsIn,Ty.RowsIn,Ty.RowsInList,Eff.RowsIn,result]
  · refine ⟨rfl,?_,?_,Or.inr ⟨rfl,rfl⟩⟩
    · intro i r k hr hk
      cases i <;> simp at hr hk
      cases hr; cases hk; trivial
    · intro r hr; simp at hr; subst r; exact ⟨by decide,by decide⟩
  · constructor
    · simp [signature,PrimSig.tel,signatureTel,Tel.instR,Tel.substRAt,
        Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,
        Ty.WF,Ty.WFList,Tel.WF,Tel.norm,Ty.norm,Eff.norm,Eff.WF,Eff.Canonical,result,
        RangeIx.inst,RangeIx.WF]
    · simp [TypeAnnotations]
    · exact ⟨rfl,by intro i a k h; cases i <;> cases h⟩
    · simp [RowAnnotations]
    · simp
    · rw [instantiated]
      exact ⟨by trivial,by trivial,⟨trivial,(result_annotation _).declared,trivial⟩⟩
  · rw [instantiated]
    refine .param ⟨trivial,trivial,trivial⟩
      (HasTypeVQ.checked_opaque rfl rfl ⟨rfl,⟨["a"],rfl⟩⟩) ?_
    simp only [Tel.bind_done]
    have hb : result.bind (Tel.argumentsEnv (.checked target)) = result := by
      simp [result,Ty.bind,Ty.rawBind,rawBindTys,Tel.argumentsEnv,Ty.norm,Ty.normTys,RangeIx.inst]
    have he : Eff.bind (Tel.argumentsEnv (.checked target)) effect = effect := by
      simp [effect,Eff.bind,Eff.rawBind,Tel.argumentsEnv,valEnv,Eff.norm,substAtoms_nil,instAtoms_nil,rowFails]
    rw [hb,he]
    exact .done ⟨⟨by trivial,by trivial⟩,⟨by trivial,by trivial⟩,
      ⟨(result_annotation _).declared,trivial⟩⟩
  · intro w hw; simp at hw; subst w; trivial
  · simp
  · simp
  · exact ⟨by trivial,rfl⟩
  · exact ⟨by simp [effect,Eff.WF,Ty.WFList,range],rfl⟩

/-- 非Topの File.readTextIn の全入力前提から、同じ対象と single を得る。 -/
example (Ψ : StoreTy) (σ : PathEnv) :
    NamesWF signature.names signature.params ∧
    builtins.ShapeOk "File.readTextIn" signature ∧
    BuiltinArgs program builtins Ψ "File.readTextIn" signature [] [] [range]
      [.checked target] result effect ∧
    ∃ r t, [range] = [r] ∧ (([.checked target] : List Val)[0]?).bind Val.target? = some t ∧
      r.Mem σ .path t ∧ signature.shapeAt [.checked target] = .single .path 0 ∧
      (Eff.instR [r] signature.eff).mem (.name "File.Read" (.fixed r)) := by
  have names : NamesWF signature.names signature.params := by simp [NamesWF,signature]
  have args := arguments Ψ
  have had : ∀ w ∈ [Val.checked target], w.Adequate σ := by simp [Val.Adequate]
  obtain ⟨r,t,hrr,ht,hm,hshape⟩ := shape.single_target rfl names args had
  cases hrr
  obtain ⟨l,o,ho,_,he,_,_⟩ := shape.single_inst rfl range
  have hl : l = "File.Read" := Option.some.inj ho.symm
  subst l
  exact ⟨names,shape,args,range,t,rfl,ht,hm,hshape,he⟩

end
end SingleTargetExamples
end Benitoite.Release.Refinement
