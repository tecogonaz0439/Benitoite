import Benitoite.Release.Refinement.SurfaceMain

/-! # 核のライブラリと表層の利用者の本体の結合

既に型付けたライブラリの本体を保持し、利用者の本体だけを脱糖する。
宣言表の対応は実際の lookup と署名の一致として受ける（設計書 01-12「確かめる性質」）。
-/
namespace Benitoite.Release.Refinement.Surface
noncomputable section

/-- 利用者の脱糖した定義を優先し、空欄にはライブラリの定義を置く。他の宣言は収集した表を使う。 -/
def linkProgram (base : Refinement.Program) (op : OpPrim) (p : Program) : Refinement.Program :=
  { desugarProgram op p with defs := fun f => ((desugarProgram op p).defs f).orElse (fun _ => base.defs f) }

/-- 本体の結合は、収集した型の宣言を変えない。 -/
theorem link_sameTypes (base : Refinement.Program) (op : OpPrim) (p : Program) :
    (desugarProgram op p).SameTypes (linkProgram base op p) := ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩

/-- 利用者の定義の lookup は結合で保たれる。 -/
theorem link_lookup {base op p f d} (h : (desugarProgram op p).defs f = some d) :
    (linkProgram base op p).defs f = some d := by simp [linkProgram, h]

/-- view は本体のソース照合だけに使う。核の宣言との対応を変えない。 -/
theorem Declarations.Realizes.withView {D : Declarations} {P : Refinement.Program} (h : D.Realizes P) (v : CoverageView) :
    (D.withView v).Realizes P := ⟨h.types,h.funs,h.impls,h.externalWF,h.ranges⟩

/-- 利用者自身の宣言は、結合後も同じ署名を実現する。 -/
theorem link_realizes {p : Program} {op : OpPrim} (base : Refinement.Program)
    (hwf : p.WellFormed) (v : CoverageView) :
    (p.declarationsFor v).Realizes (linkProgram base op p) := by
  have h := declarationsFor_realizes (op := op) hwf v
  have hs := link_sameTypes base op p
  refine ⟨?_, ?_, ?_, h.externalWF.sameTypes hs, ?_⟩
  · exact ⟨h.types.cons, h.types.ops, h.types.effects, h.types.classes, h.types.externals, h.types.dataInfo⟩
  · intro f fd hf
    obtain ⟨d, hd, rest⟩ := h.funs f fd hf
    exact ⟨d, link_lookup hd, rest⟩
  · exact h.impls
  · intro f fd hf d hd
    obtain ⟨sd, hsd, _⟩ := h.funs f fd hf
    have hsd' := link_lookup (base := base) hsd
    rw [hd] at hsd'
    have hdEq := Option.some.inj hsd'
    subst d
    exact h.ranges f fd hf sd hsd

/-- 宣言の補完を使った表層の検査から、追加された全宣言の義務を得る。 -/
theorem link_additions {p : Program} {q : Check.Input} (base : Refinement.Program)
    (hwf : p.WellFormed) (hchecked : CheckTables.CheckedUnder p q)
    (hR : q.D.Realizes (linkProgram base q.opPrim p))
    (hA : Builtins.ValueAssumptions (linkProgram base q.opPrim p) q.B) :
    Refinement.Program.Additions base (linkProgram base q.opPrim p) q.B := by
  let P := linkProgram base q.opPrim p
  have hS : p.declarations.core.SameTypes P := ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩
  have hOwn := link_realizes (op := q.opPrim) base hwf closedView
  have hv := hchecked.variance.sameTypes hR.types
  have he : P.EffectsOk q.B := by
    have ho : q.D.core.ops = P.ops := hR.types.ops
    have he : q.D.core.effects = P.effects := hR.types.effects
    exact ⟨fun l os o hl hm => by
        have h := hchecked.effects.1 l os o (he ▸ hl) hm
        simpa only [ho] using h,
      fun o od hod => by
        have h := hchecked.effects.2.1 o od (ho ▸ hod)
        simpa only [he] using h,
      fun l os hl => hchecked.effects.2.2 l os (he ▸ hl)⟩
  constructor
  case defs =>
    intro f d hbase hd
    have hraw : (desugarProgram q.opPrim p).defs f = some d := by
      change (((desugarProgram q.opPrim p).defs f).orElse (fun _ => base.defs f)) = some d at hd
      cases hx : (desugarProgram q.opPrim p).defs f with
      | none => simp [hx,hbase] at hd
      | some v => simpa only [hx,Option.orElse_some] using hd
    rcases lookupFun_desugar hraw with ⟨sd, hsd, rfl⟩ | ⟨hnd,c,k,cd,ha,hc,rfl⟩ | ⟨hnd,hna,c,cd,ht,hc,rfl⟩
    · have hw := hchecked.defs f sd hsd
      obtain ⟨hn,hsig,hsc⟩ := hwf.defs f sd hsd
      have hb := hw.2.2.2.scoped (ne := sd.neffs) (by
        simpa [FunDecl.tel, telBinders_signatureTel _ _ _ _ hn.1] using hsc)
      exact ⟨hw.desugar (hR.withView _) hA, hn, signatureScopedR_sameTypes hsig hS,
        by simpa [FunDecl.tel, telBinders_signatureTel _ _ _ _ hn.1, desugarDef, Refinement.Def.ntys] using hb⟩
    · obtain ⟨hk,hann,hsig,rest⟩ := hwf.accessors f c k ha hnd cd hc
      refine ⟨accessorDef_wellTyped hOwn ⟨hk,hann,hsig,rest⟩,
        by simp [accessorDef, accessorDecl, NamesWF], ?_, ?_⟩
      · have hs := hsig.sameTypes hS
        exact ⟨hs.1,hs.2.1,hs.2.2.1,Ty.annotationR_nil.mpr hs.2.2.2⟩
      · simp only [accessorDef, mkArm, Comp.SourceScoped, Val.SourceScoped, scopedArms]
        exact ⟨by simp [accessorDecl],trivial,by simp only [accessorDecl,List.length_cons,List.length_nil]; omega,trivial⟩
    · obtain ⟨_,_,hok⟩ := hwf.testers f c ht
      obtain ⟨hk,hann,hsig,rest⟩ := hok cd hc
      refine ⟨testerDef_wellTyped hOwn (by simpa [linkProgram,desugarProgram] using hc) ⟨hk,hann,hsig,rest⟩,
        by simp [testerDef,testerDecl,NamesWF], ?_, ?_⟩
      · have hs := hsig.sameTypes hS
        exact ⟨hs.1,hs.2.1,hs.2.2.1,Ty.annotationR_nil.mpr hs.2.2.2⟩
      · simp only [testerDef,mkArm,Comp.SourceScoped,Val.SourceScoped,scopedArms]
        exact ⟨by simp [testerDecl],trivial,trivial,trivial,trivial,trivial⟩
  case impls =>
    intro i id _ hid
    change (p.impls i).map (desugarImpl q.opPrim) = some id at hid
    obtain ⟨sid,hsid,rfl⟩ := Option.map_eq_some_iff.mp hid
    have hw := hchecked.impls i sid hsid
    obtain ⟨h1,h2,h3,h4,h5,h6,h7⟩ := hwf.impls i sid hsid
    have htyped := ImplDecl.WellTyped.desugar (D := q.D) (views := p.methodViews i) hw (fun v => hR.withView v) hR hA
    obtain ⟨cd0,hcd0,_,_,_,_,hbodies,_⟩ := hw
    refine ⟨htyped,
      h1,h2,h3.sameTypes hS,h4.sameTypes hS,fun a ha => (h5 a ha).sameTypes hS,?_,?_⟩
    · intro s u hu
      obtain ⟨d,hd,rfl⟩ := Option.map_eq_some_iff.mp hu
      exact DictEv.Scoped.toVal (h6 s d hd)
    · intro cd m ms body hcd hms hbody
      obtain ⟨sb,hsb,rfl⟩ := Option.map_eq_some_iff.mp hbody
      have hcd' : q.D.classes sid.cls = some cd := hR.classes ▸ hcd
      rw [hcd0] at hcd'; cases hcd'
      obtain ⟨sb',hsb',hn,hbt⟩ := hbodies m ms hms
      rw [hsb] at hsb'; cases hsb'
      have hlen : ∀ k, telBinders (Tel.shiftV k 0
          (Tel.bind (typeEnvAt ms.tparams.length [sid.target] []) ms.tel)) = ms.params.length := by
        intro k
        rw [telBinders_shiftV,telBinders_bind,MethSig.tel,telBinders_signatureTel _ _ _ _ hn.1]
      have hb := hbt.scoped (ne := ms.neffs) (by
        simpa [hlen,bindParams,TypeCtx.values,ImplSig.dictTys] using h7 cd0 m ms sb hcd hms hsb)
      simpa [hlen,bindParams,TypeCtx.values,ImplSig.dictTys,ImplDecl.dictTys,desugarImpl] using hb
  case cons => intro c cd _ hc; exact ⟨(hS.dataArity _ _).mp (hwf.types.cons c cd hc).1,
    (hwf.types.cons c cd hc).2.sameTypes hS⟩
  case ops => intro o od _ ho; exact (hwf.types.ops o od ho).sameTypes hS
  case classes => intro c cd _ hc; exact (hwf.types.classes c cd hc).sameTypes hS
  case metadata => exact hwf.types.metadata.sameTypes hS
  case dataVariance => intro d info _ hi; exact hv.1 d info hi
  case conVariance => intro c cd _ hc; exact hv.2 c cd hc
  case effectOps => intro l os o _ hl ho; exact he.1 l os o hl ho
  case opEffects => intro o od _ ho; exact he.2.1 o od ho
  case builtinEffects => intro l os _ hl; exact he.2.2 l os hl

/-- 同じ完成した表で検査した利用者の本体と、保持した標準本体へ主定理を適用する。
`Realizes.externalWF` は `hI.externalWF hw` から供給できる。宣言表の実現を構成するときに
この証拠を使い、外部宣言の整形式を独立の信頼条件として重ねない。 -/
theorem surface_guarantees {p : Program} {q : Check.Input}
    {L : StandardModel.NameLists} (hL : L.WF) {externals}
    (T : StandardModel.DataTable (linkProgram (StandardModel.program externals) q.opPrim p))
    {A : StandardModel.AssumedTable} (hB : q.B = StandardModel.complete L T A)
    (hI : StandardModel.Includes externals (linkProgram (StandardModel.program externals) q.opPrim p))
    (hR : q.D.Realizes (linkProgram (StandardModel.program externals) q.opPrim p))
    (hc : StandardModel.Completion L T A) (hw : (StandardModel.program externals).ExternalWF)
    (hwf : p.WellFormed) (hchecked : CheckTables.CheckedUnder p q) (σ : PathEnv) :
    ProgramGuarantees (linkProgram (StandardModel.program externals) q.opPrim p) (StandardModel.complete L T A) σ := by
  have hcore := (StandardModel.completion_core L externals hL _ T A hI hc).1
  have hadd := link_additions _ hwf hchecked hR (hB ▸ hcore.values)
  exact StandardModel.included_guarantees hL T hI hc hw (hB ▸ hadd) σ

/-- 開始の閉包の型付けと、開始からの効果・対象の結論。 -/
structure MainGuarantees (P : Refinement.Program) (B : Builtins) (σ : PathEnv) (ε : Eff) : Prop where
  initial : StateTyE P B σ ε (.run mainClosure [] Store.empty)
  effect : ε = Eff.empty → ∀ evs s, Steps P B σ (.run mainClosure [] Store.empty) evs s →
    (∀ ev s', ¬ Step P B σ s (some ev) s') ∧ ¬ UnhandledOp s
  target : ∀ evs s s' b ws o obs, Steps P B σ (.run mainClosure [] Store.empty) evs s →
    Step P B σ s (some (.io b ws o obs)) s' →
    ∃ e l, B.sig b = some e ∧ e.opEff = some l ∧ ∀ t ∈ obs, Eff.Allows σ B.effKind ε l t

/-- ライブラリを保持した表層の main から、開始・効果・対象の性質を得る。 -/
theorem linked_main {p : Program} {q : Check.Input}
    {L : StandardModel.NameLists} (hL : L.WF) {externals}
    (T : StandardModel.DataTable (linkProgram (StandardModel.program externals) q.opPrim p))
    {A : StandardModel.AssumedTable} (hB : q.B = StandardModel.complete L T A)
    (hI : StandardModel.Includes externals (linkProgram (StandardModel.program externals) q.opPrim p))
    (hR : q.D.Realizes (linkProgram (StandardModel.program externals) q.opPrim p))
    (hc : StandardModel.Completion L T A) (hw : (StandardModel.program externals).ExternalWF)
    (hwf : p.WellFormed) (hchecked : CheckTables.CheckedUnder p q) {σ : PathEnv} {ε : Eff}
    (hm : p.HasMain ε)
    (hr : σ.Ready (linkProgram (StandardModel.program externals) q.opPrim p)
      (StandardModel.complete L T A) (.run mainClosure [] Store.empty)) :
    MainGuarantees (linkProgram (StandardModel.program externals) q.opPrim p) (StandardModel.complete L T A) σ ε := by
  have hg := surface_guarantees hL T hB hI hR hc hw hwf hchecked σ
  obtain ⟨a,hmret,hann,ht⟩ := main_typed_realized (B := StandardModel.complete L T A) (op := q.opPrim)
    hwf hm (link_realizes _ hwf closedView).types (fun _ _ h => link_lookup h)
  have hnorm : a.Normal := by rcases hmret with rfl | rfl <;> rfl
  have hq := ClosureTy.pure ht hann (by intro r h; cases h) hnorm (by intro r h; cases h)
  have hs := StartCondition.of_noLamNames ht (σ := σ) (by constructor <;> trivial)
    (by simp [Comp.ClosedNoLamNames,Val.ClosedNoLamNames,Val.ClosedNoLamNamesList]) ⟨hr⟩
  exact ⟨hg.initial_typing _ _ _ hq hs,fun he => by subst ε; exact hg.effect_soundness _ _ hq hs,
    hg.reachable_target_sound _ _ _ hq hs⟩

/-- 型付けと必須の判定の受理の成功を、標準の本体を保持した利用者のプログラムへ適用する。 -/
theorem checkProgramAccepted_guarantees {p : Program} {q : Check.Input} {Ai : CheckAccept.AcceptInput}
    (hq : q.Sound) (hn : CheckTables.NamesComplete q p)
    (hd : ∀ n d, p.defs n = some d → CheckDeclarations.DefSupport q d)
    (hi : ∀ n id, p.impls n = some id → CheckDeclarations.ImplSupport q id)
    (him : ∀ n id, p.impls n = some id → CheckDeclarations.ImplNamesComplete q id)
    (hext : CheckTables.Extends q.D p.declarations) (ha : CheckAccept.NamesComplete q p)
    (haccept : CheckAccept.checkProgramAccepted q Ai p = .ok ())
    {L : StandardModel.NameLists} (hL : L.WF) {externals}
    (T : StandardModel.DataTable (linkProgram (StandardModel.program externals) q.opPrim p))
    {A : StandardModel.AssumedTable} (hB : q.B = StandardModel.complete L T A)
    (hI : StandardModel.Includes externals (linkProgram (StandardModel.program externals) q.opPrim p))
    (hR : q.D.Realizes (linkProgram (StandardModel.program externals) q.opPrim p))
    (hc : StandardModel.Completion L T A) (hw : (StandardModel.program externals).ExternalWF)
    (hwf : p.WellFormed) (σ : PathEnv) :
    CheckAccept.Accepted Ai q p ∧
      ProgramGuarantees (linkProgram (StandardModel.program externals) q.opPrim p) (StandardModel.complete L T A) σ := by
  obtain ⟨hchecked,hacc⟩ := CheckAccept.checkProgramAccepted_sound hq hn hd hi him hext ha haccept
  exact ⟨hacc,surface_guarantees hL T hB hI hR hc hw hwf hchecked σ⟩

/-- 型付けと必須の判定の受理の成功を、標準の本体を保持した利用者のプログラムへ適用する。 -/
theorem checkProgramAccepted_main {p : Program} {q : Check.Input} {Ai : CheckAccept.AcceptInput}
    (hq : q.Sound) (hn : CheckTables.NamesComplete q p)
    (hd : ∀ n d, p.defs n = some d → CheckDeclarations.DefSupport q d)
    (hi : ∀ n id, p.impls n = some id → CheckDeclarations.ImplSupport q id)
    (him : ∀ n id, p.impls n = some id → CheckDeclarations.ImplNamesComplete q id)
    (hext : CheckTables.Extends q.D p.declarations) (ha : CheckAccept.NamesComplete q p)
    (haccept : CheckAccept.checkProgramAccepted q Ai p = .ok ())
    {L : StandardModel.NameLists} (hL : L.WF) {externals}
    (T : StandardModel.DataTable (linkProgram (StandardModel.program externals) q.opPrim p))
    {A : StandardModel.AssumedTable} (hB : q.B = StandardModel.complete L T A)
    (hI : StandardModel.Includes externals (linkProgram (StandardModel.program externals) q.opPrim p))
    (hR : q.D.Realizes (linkProgram (StandardModel.program externals) q.opPrim p))
    (hc : StandardModel.Completion L T A) (hw : (StandardModel.program externals).ExternalWF)
    (hwf : p.WellFormed) {σ : PathEnv} {ε : Eff} (hm : p.HasMain ε)
    (hr : σ.Ready (linkProgram (StandardModel.program externals) q.opPrim p)
      (StandardModel.complete L T A) (.run mainClosure [] Store.empty)) :
    CheckAccept.Accepted Ai q p ∧
      ProgramGuarantees (linkProgram (StandardModel.program externals) q.opPrim p) (StandardModel.complete L T A) σ ∧
      MainGuarantees (linkProgram (StandardModel.program externals) q.opPrim p) (StandardModel.complete L T A) σ ε := by
  obtain ⟨hacc,hg⟩ := checkProgramAccepted_guarantees hq hn hd hi him hext ha haccept
    hL T hB hI hR hc hw hwf σ
  obtain ⟨hchecked,_⟩ := CheckAccept.checkProgramAccepted_sound hq hn hd hi him hext ha haccept
  exact ⟨hacc,hg,linked_main hL T hB hI hR hc hw hwf hchecked hm hr⟩

end
end Benitoite.Release.Refinement.Surface
