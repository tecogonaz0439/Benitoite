import Benitoite.Release.Refinement.MainStatements

/-! # ラムダ名の整形式を外した閉じ方

閉じ方 `Comp.ClosedAt`（設計書 07-04「篩を含む形式化の範囲」）は、表層のラムダ `.lam ns ps body` に契約名の整形式
`NamesWF ns ps` を要求する。ここでは、その条件を外した閉じ方 `Comp.ClosedNoLamNames` を定め、型が付いた計算では
二つの閉じ方が一致することを示す。名前の整形式は各ラムダの `V_Lam` の前提が供給する。

外した閉じ方は、元の閉じ方が中を読むところをすべて同じ形で辿る。At の呼出しの起点・パターン・入力の値、実行時の閉包
`.closure` の本体、保持した要求の中のラムダも対象である。型付けの証拠から閉性を得られるところは、その証拠を使い、
外した閉じ方には条件を置かない。実行時の閉包の捕捉値の閉性は `CaptureOk` の Ground の前提から、実行時の入力の
望遠鏡の整形式は `Tel.RuntimeShape` から、保持した要求の閉性は `groundVal` の前提から得る。

型付けは局所参照を解決する前の計算に付き、開始の閉包の本体は解決した後の計算である。そこで、型付けからの証明は
任意の解決 `resolveLocals ρ` の後の計算について示す。解決は局所参照だけを置き換え、名前と閉じ方の他の条件を変えない。
-/
namespace Benitoite.Release.Refinement

private def localBoundNoNames (n : Nat) : LocalRef → Prop
  | .bound i => i < n
  | .loc _ => True
private def builderBoundNoNames (nt n : Nat) : BuilderKind → Prop
  | .list a => a.WF 0 nt n
  | _ => True

mutual
  /-- 値の閉じ方から、表層のラムダの契約名の整形式を外したもの。型付けが閉性を与える実行時の閉包の捕捉値と入力の
  望遠鏡、保持した要求には条件を置かない。 -/
  def Val.ClosedNoLamNames (nt nv : Nat) : Val → Prop
    | .var i => i < nv
    | .const _ | .loc _ | .bytesV _ | .checked _ | .pathBases _ | .scopePattern _ | .atError _ => True
    | .checkedAt _ _ _ _ => True
    | .fnRef _ ts es => (∀ a ∈ ts, a.WF 0 nt nv) ∧ (∀ e ∈ es, Eff.WF 0 nt nv e ∧ e.Canonical)
    | .prim _ ts es rs => (∀ a ∈ ts, a.WF 0 nt nv) ∧
        (∀ e ∈ es, Eff.WF 0 nt nv e ∧ e.Canonical) ∧ (∀ r ∈ rs, r.WF)
    | .externalRef _ ts | .externalHandle _ ts => ∀ a ∈ ts, a.WF 0 nt nv
    | .lam _ ps body => (∀ a ∈ ps, a.WF 0 nt nv) ∧ Comp.ClosedNoLamNames nt (nv + ps.length) body
    | .dependentLam t body => Tel.WF 0 nt nv t ∧ Comp.ClosedNoLamNames nt (nv + telBinders t) body
    | .closure t q => Closure.ClosedNoLamNames (telBinders t) q
    | .con _ ts vs | .dict _ ts vs => (∀ a ∈ ts, a.WF 0 nt nv) ∧ Val.ClosedNoLamNamesList nt nv vs
    | .list vs | .setV vs => Val.ClosedNoLamNamesList nt nv vs
    | .op _ ts => ∀ a ∈ ts, a.WF 0 nt nv
    | .raise a e => a.WF 0 nt nv ∧ e.WF 0 nt nv
    | .mapV ks vs => Val.ClosedNoLamNamesList nt nv ks ∧ Val.ClosedNoLamNamesList nt nv vs
    | .super v _ => v.ClosedNoLamNames nt nv
    | .checkedRequest _ _ => True
  def Val.ClosedNoLamNamesList (nt nv : Nat) : List Val → Prop
    | [] => True
    | v :: vs => v.ClosedNoLamNames nt nv ∧ Val.ClosedNoLamNamesList nt nv vs
  /-- 計算の閉じ方から、表層のラムダの契約名の整形式を外したもの。 -/
  def Comp.ClosedNoLamNames (nt nv : Nat) : Comp → Prop
    | .builderLet b m => builderBoundNoNames nt nv b ∧ m.ClosedNoLamNames nt (nv+1)
    | .builderOp b _ r vs => builderBoundNoNames nt nv b ∧ localBoundNoNames nv r ∧
        Val.ClosedNoLamNamesList nt nv vs
    | .ret v | .escape v => v.ClosedNoLamNames nt nv
    | .letIn m n => m.ClosedNoLamNames nt nv ∧ n.ClosedNoLamNames nt (nv+1)
    | .app v vs => v.ClosedNoLamNames nt nv ∧ Val.ClosedNoLamNamesList nt nv vs
    | .ite v m n => v.ClosedNoLamNames nt nv ∧ m.ClosedNoLamNames nt nv ∧ n.ClosedNoLamNames nt nv
    | .match v arms => v.ClosedNoLamNames nt nv ∧ Arm.ClosedNoLamNamesList nt nv arms
    | .lazyC m => m.ClosedNoLamNames nt nv
    | .use v m => v.ClosedNoLamNames nt nv ∧ m.ClosedNoLamNames nt nv
    | .handle m cs => m.ClosedNoLamNames nt nv ∧ Clause.ClosedNoLamNamesList nt nv cs
    | .resume k v => k.ClosedNoLamNames nt nv ∧ v.ClosedNoLamNames nt nv
    | .meth v _ ts es vs => v.ClosedNoLamNames nt nv ∧ (∀ a ∈ ts, a.WF 0 nt nv) ∧
        (∀ e ∈ es, Eff.WF 0 nt nv e ∧ e.Canonical) ∧ Val.ClosedNoLamNamesList nt nv vs
    | .issuePathBases _ => True
    | .checkAt _ _ shape bases p v ix => shape.errorType.WF 0 nt nv ∧ ix.WF 0 ∧
        (match bases with | none => True | some b => b.ClosedNoLamNames nt nv) ∧
        p.ClosedNoLamNames nt nv ∧ v.ClosedNoLamNames nt nv
    | .externalCall _ ts vs => (∀ a ∈ ts, a.WF 0 nt nv) ∧ Val.ClosedNoLamNamesList nt nv vs
  def Arm.ClosedNoLamNamesList (nt nv : Nat) : List Arm → Prop
    | [] => True
    | .mk alts guard body :: arms =>
        (match guard with
          | none => True
          | some g => g.ClosedNoLamNames nt (nv + Benitoite.Release.Arm.bindersOf alts)) ∧
        body.ClosedNoLamNames nt (nv + Benitoite.Release.Arm.bindersOf alts) ∧
        Arm.ClosedNoLamNamesList nt nv arms
  def Clause.ClosedNoLamNamesList (nt nv : Nat) : List Clause → Prop
    | [] => True
    | .mk _ arity ntys body :: cs => body.ClosedNoLamNames (nt+ntys) (nv+arity+1) ∧
        Clause.ClosedNoLamNamesList nt nv cs
    | .fail e body :: cs => e.WF 0 nt nv ∧ body.ClosedNoLamNames (nt+1) (nv+2) ∧
        Clause.ClosedNoLamNamesList nt nv cs
  /-- 閉包の閉じ方から、表層のラムダの契約名の整形式を外したもの。捕捉値の閉性は条件にしない。 -/
  def Closure.ClosedNoLamNames (inputs : Nat) : Closure → Prop
    | .mk cap m => m.ClosedNoLamNames 0 (cap.values.length + inputs)
end

/-- 保持した要求の証拠は、要求の `groundVal` を前提に持つので、保持した要求は閉じている。 -/
theorem CheckedWitness.request_closed {P B Ψ o k range snapshot target request}
    (h : CheckedWitness P B Ψ o k range snapshot target request) :
    ∀ v, request = some v → v.ClosedAt 0 0 := by
  cases h with
  | plain => intro v hv; cases hv
  | request _ _ _ hg _ _ => intro v hv; cases hv; exact groundVal_ground hg

private theorem builderOp_closed {nt nv : Nat} {b : BuilderKind} {op} {r : LocalRef} {vs : List Val}
    (hb : builderBoundNoNames nt nv b) (hr : localBoundNoNames nv r) (hvs : Val.ClosedList nt nv vs) :
    (Comp.builderOp b op r vs).ClosedAt nt nv := by
  refine ⟨?_,?_,hvs⟩
  · cases b <;> exact hb
  · cases r <;> exact hr

mutual
  /-- 型が付いた値では、局所参照を解決した後も、ラムダ名の整形式を外した閉じ方から元の閉じ方を得る。 -/
  theorem HasTypeVQ.closed_noLamNames_resolved {P B Ψ Q C Γ Φ v a}
      (h : HasTypeVQ P B Ψ Q C Γ Φ v a) : ∀ (ρ : Nat → LocalRef) (nt nv : Nat),
      (v.resolveLocals ρ).ClosedNoLamNames nt nv → (v.resolveLocals ρ).ClosedAt nt nv := by
    match h with
    | .V_Lam hn _ _ hb _ =>
      intro ρ nt nv hc
      exact ⟨hn,hc.1,hb.closed_noLamNames_resolved _ _ _ hc.2⟩
    | .V_DependentLam _ hb =>
      intro ρ nt nv hc
      exact ⟨hc.1,hb.closed_noLamNames_resolved _ _ _ hc.2⟩
    | .V_Closure _ hshape hd =>
      intro ρ nt nv hc
      exact ⟨hshape.runtime_wf,hd.closed_noLamNames _ hc⟩
    | .V_Map hk hv _ _ _ _ =>
      intro ρ nt nv hc
      exact ⟨hk.closed_noLamNames_resolved _ _ _ hc.1,hv.closed_noLamNames_resolved _ _ _ hc.2⟩
    | .V_Set hv _ _ =>
      intro ρ nt nv hc
      exact hv.closed_noLamNames_resolved _ _ _ hc
    | .V_Dict _ _ _ _ _ _ hv _ =>
      intro ρ nt nv hc
      exact ⟨hc.1,hv.closed_noLamNames_resolved _ _ _ hc.2⟩
    | .V_Con _ _ _ _ hv _ =>
      intro ρ nt nv hc
      exact ⟨hc.1,hv.closed_noLamNames_resolved _ _ _ hc.2⟩
    | .V_Super hv _ _ _ =>
      intro ρ nt nv hc
      exact hv.closed_noLamNames_resolved _ _ _ hc
    | .V_List hv _ _ _ =>
      intro ρ nt nv hc
      exact hv.closed_noLamNames_resolved _ _ _ hc
    | .V_Sub hv _ _ _ _ =>
      intro ρ nt nv hc
      exact hv.closed_noLamNames_resolved _ _ _ hc
    | .V_Normal hv =>
      intro ρ nt nv hc
      exact hv.closed_noLamNames_resolved _ _ _ hc
    | .V_Refine hv _ _ _ _ _ _ _ =>
      intro ρ nt nv hc
      exact hv.closed_noLamNames_resolved _ _ _ hc
    | .V_CheckedAt (request := r) hw =>
      intro ρ nt nv _
      cases r with
      | none => trivial
      | some w => exact hw.request_closed w rfl
    | .V_CheckedRequest _ _ _ hg _ _ =>
      intro ρ nt nv _
      exact groundVal_ground hg
    | .V_Var .. | .V_Const .. | .V_Fun .. | .V_Prim .. |
      .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. |
      .V_ScopePattern .. | .V_Checked .. |
      .V_AtError .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. =>
      intro ρ nt nv hc
      exact hc
  termination_by structural h

  theorem HasTypeVsQ.closed_noLamNames_resolved {P B Ψ Q C Γ Φ vs as}
      (h : HasTypeVsQ P B Ψ Q C Γ Φ vs as) : ∀ (ρ : Nat → LocalRef) (nt nv : Nat),
      Val.ClosedNoLamNamesList nt nv (Val.resolveLocalsList ρ vs) →
      Val.ClosedList nt nv (Val.resolveLocalsList ρ vs) := by
    match h with
    | .nil =>
      intro ρ nt nv hc
      trivial
    | .cons hv hvs =>
      intro ρ nt nv hc
      exact ⟨hv.closed_noLamNames_resolved _ _ _ hc.1,hvs.closed_noLamNames_resolved _ _ _ hc.2⟩
  termination_by structural h

  theorem HasTypeEachQ.closed_noLamNames_resolved {P B Ψ Q C Γ Φ vs a}
      (h : HasTypeEachQ P B Ψ Q C Γ Φ vs a) : ∀ (ρ : Nat → LocalRef) (nt nv : Nat),
      Val.ClosedNoLamNamesList nt nv (Val.resolveLocalsList ρ vs) →
      Val.ClosedList nt nv (Val.resolveLocalsList ρ vs) := by
    match h with
    | .nil =>
      intro ρ nt nv hc
      trivial
    | .cons hv hvs =>
      intro ρ nt nv hc
      exact ⟨hv.closed_noLamNames_resolved _ _ _ hc.1,hvs.closed_noLamNames_resolved _ _ _ hc.2⟩
  termination_by structural h

  theorem HasTypeTelArgsQ.closed_noLamNames_resolved {P B Ψ Q C Γ Φ vs t a e}
      (h : HasTypeTelArgsQ P B Ψ Q C Γ Φ vs t a e) : ∀ (ρ : Nat → LocalRef) (nt nv : Nat),
      Val.ClosedNoLamNamesList nt nv (Val.resolveLocalsList ρ vs) →
      Val.ClosedList nt nv (Val.resolveLocalsList ρ vs) := by
    match h with
    | .done _ =>
      intro ρ nt nv hc
      trivial
    | .param _ hv hvs =>
      intro ρ nt nv hc
      exact ⟨hv.closed_noLamNames_resolved _ _ _ hc.1,hvs.closed_noLamNames_resolved _ _ _ hc.2⟩
  termination_by structural h

  theorem TelBodyTy.closed_noLamNames_resolved {P B Ψ Q C Γ Φ t body}
      (h : TelBodyTy P B Ψ Q C Γ Φ t body) : ∀ (ρ : Nat → LocalRef) (nt nv : Nat),
      (body.resolveLocals ρ).ClosedNoLamNames nt nv → (body.resolveLocals ρ).ClosedAt nt nv := by
    match h with
    | .done hb =>
      intro ρ nt nv hc
      exact hb.closed_noLamNames_resolved _ _ _ hc
    | .param hb =>
      intro ρ nt nv hc
      exact hb.closed_noLamNames_resolved _ _ _ hc
  termination_by structural h

  /-- 実行時の閉包の型付けでは、捕捉は `CaptureOk` の Ground の前提で閉じ、本体は型付けから元の閉じ方を得る。 -/
  theorem DependentClosureTy.closed_noLamNames {P B Ψ q t}
      (h : DependentClosureTy P B Ψ q t) : ∀ (inputs : Nat), q.ClosedNoLamNames inputs → q.ClosedAt inputs := by
    match h with
    | .mk hcap hb _ _ =>
      intro inputs hc
      refine ⟨hcap.closed,?_⟩
      have hr := hb.closed_noLamNames_resolved LocalRef.bound 0 _ (by rw [Comp.resolveLocals_id]; exact hc)
      rwa [Comp.resolveLocals_id] at hr
  termination_by structural h

  /-- At の呼出しの起点・パターン・入力の値は、許容の前提の型付けから元の閉じ方を得る。 -/
  theorem AtCallAdmissible.closed_noLamNames_resolved {P B Ψ Q C Γ Φ kind name shape bases pattern input index}
      (h : AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index) :
      ∀ (ρ : Nat → LocalRef) (nt nv : Nat),
        (∀ b, bases = some b → (b.resolveLocals ρ).ClosedNoLamNames nt nv → (b.resolveLocals ρ).ClosedAt nt nv) ∧
        ((pattern.resolveLocals ρ).ClosedNoLamNames nt nv → (pattern.resolveLocals ρ).ClosedAt nt nv) ∧
        ((input.resolveLocals ρ).ClosedNoLamNames nt nv → (input.resolveLocals ρ).ClosedAt nt nv) := by
    match h with
    | .mk _ _ hb hp _ hi _ _ =>
      intro ρ nt nv
      exact ⟨fun b e => (hb b e).closed_noLamNames_resolved ρ nt nv,
        hp.closed_noLamNames_resolved ρ nt nv,hi.closed_noLamNames_resolved ρ nt nv⟩
    | .text _ _ hb hp _ hi _ _ =>
      intro ρ nt nv
      exact ⟨fun b e => (hb b e).closed_noLamNames_resolved ρ nt nv,
        hp.closed_noLamNames_resolved ρ nt nv,hi.closed_noLamNames_resolved ρ nt nv⟩
  termination_by structural h

  /-- 型が付いた計算では、局所参照を解決した後も、ラムダ名の整形式を外した閉じ方から元の閉じ方を得る。 -/
  theorem HasTypeCQ.closed_noLamNames_resolved {P B Ψ Q C Γ Φ R m a e L}
      (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) : ∀ (ρ : Nat → LocalRef) (nt nv : Nat),
      (m.resolveLocals ρ).ClosedNoLamNames nt nv → (m.resolveLocals ρ).ClosedAt nt nv := by
    match h with
    | .C_BuilderLet (kind := kind) _ _ hb _ =>
      intro ρ nt nv hc
      refine ⟨?_,hb.closed_noLamNames_resolved _ _ _ hc.2⟩
      cases kind <;> exact hc.1
    | .C_BuilderOp _ _ _ hargs =>
      intro ρ nt nv hc
      exact builderOp_closed hc.1 hc.2.1 (hargs.closed_noLamNames_resolved _ _ _ hc.2.2)
    | .C_Return hv =>
      intro ρ nt nv hc
      exact hv.closed_noLamNames_resolved _ _ _ hc
    | .C_Let hm hn _ =>
      intro ρ nt nv hc
      exact ⟨hm.closed_noLamNames_resolved _ _ _ hc.1,hn.closed_noLamNames_resolved _ _ _ hc.2⟩
    | .C_App hf hargs =>
      intro ρ nt nv hc
      exact ⟨hf.closed_noLamNames_resolved _ _ _ hc.1,hargs.closed_noLamNames_resolved _ _ _ hc.2⟩
    | .C_DependentApp hf hargs =>
      intro ρ nt nv hc
      exact ⟨hf.closed_noLamNames_resolved _ _ _ hc.1,hargs.closed_noLamNames_resolved _ _ _ hc.2⟩
    | .C_If hv _ hm hn =>
      intro ρ nt nv hc
      exact ⟨hv.closed_noLamNames_resolved _ _ _ hc.1,hm.closed_noLamNames_resolved _ _ _ hc.2.1,
        hn.closed_noLamNames_resolved _ _ _ hc.2.2⟩
    | .C_Match hv _ harms _ =>
      intro ρ nt nv hc
      exact ⟨hv.closed_noLamNames_resolved _ _ _ hc.1,harms.closed_noLamNames_resolved _ _ _ hc.2⟩
    | .C_Lazy hm _ =>
      intro ρ nt nv hc
      exact hm.closed_noLamNames_resolved _ _ _ hc
    | .C_Escape hv _ =>
      intro ρ nt nv hc
      exact hv.closed_noLamNames_resolved _ _ _ hc
    | .C_Use hv _ hm _ =>
      intro ρ nt nv hc
      exact ⟨hv.closed_noLamNames_resolved _ _ _ hc.1,hm.closed_noLamNames_resolved _ _ _ hc.2⟩
    | .C_Handle hm _ hcs =>
      intro ρ nt nv hc
      exact ⟨hm.closed_noLamNames_resolved _ _ _ hc.1,hcs.closed_noLamNames_resolved _ _ _ hc.2⟩
    | .C_Handle_Fail hm _ _ hf =>
      intro ρ nt nv hc
      exact ⟨hm.closed_noLamNames_resolved _ _ _ hc.1,hf.closed_noLamNames_resolved _ _ _ hc.2⟩
    | .C_Resume _ hv _ =>
      intro ρ nt nv hc
      exact ⟨hc.1,hv.closed_noLamNames_resolved _ _ _ hc.2⟩
    | .C_ResumeL _ hv _ =>
      intro ρ nt nv hc
      exact ⟨hc.1,hv.closed_noLamNames_resolved _ _ _ hc.2⟩
    | .C_ResumeNorm _ hv _ =>
      intro ρ nt nv hc
      exact ⟨hc.1,hv.closed_noLamNames_resolved _ _ _ hc.2⟩
    | .C_ResumeLNorm _ _ hv _ =>
      intro ρ nt nv hc
      exact ⟨hc.1,hv.closed_noLamNames_resolved _ _ _ hc.2⟩
    | .C_Normal hm =>
      intro ρ nt nv hc
      exact hm.closed_noLamNames_resolved _ _ _ hc
    | .C_Sub hm _ _ _ _ _ =>
      intro ρ nt nv hc
      exact hm.closed_noLamNames_resolved _ _ _ hc
    | .C_Eff hm _ =>
      intro ρ nt nv hc
      exact hm.closed_noLamNames_resolved _ _ _ hc
    | .C_Meth hv _ _ _ _ _ _ _ hws _ =>
      intro ρ nt nv hc
      exact ⟨hv.closed_noLamNames_resolved _ _ _ hc.1,hc.2.1,hc.2.2.1,
        hws.closed_noLamNames_resolved _ _ _ hc.2.2.2⟩
    | .C_External _ _ _ hargs =>
      intro ρ nt nv hc
      exact ⟨hc.1,hargs.closed_noLamNames_resolved _ _ _ hc.2⟩
    | .C_IssuePathBases .. =>
      intro ρ nt nv hc
      trivial
    | .C_CheckAt (bases := bases) ha =>
      intro ρ nt nv hc
      have hA := ha.closed_noLamNames_resolved ρ nt nv
      cases bases with
      | none => exact ⟨hc.1,hc.2.1,trivial,hA.2.1 hc.2.2.2.1,hA.2.2 hc.2.2.2.2⟩
      | some b => exact ⟨hc.1,hc.2.1,hA.1 b rfl hc.2.2.1,hA.2.1 hc.2.2.2.1,hA.2.2 hc.2.2.2.2⟩
  termination_by structural h

  theorem HasTypeArmsQ.closed_noLamNames_resolved {P B Ψ Q C Γ Φ R obs arms a b ε L}
      (h : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b ε L) : ∀ (ρ : Nat → LocalRef) (nt nv : Nat),
      Arm.ClosedNoLamNamesList nt nv (Arm.resolveLocalsList ρ arms) →
      Arm.ClosedList nt nv (Arm.resolveLocalsList ρ arms) := by
    match h with
    | .nil _ =>
      intro ρ nt nv hc
      trivial
    | .plain _ _ _ _ hb hrest =>
      intro ρ nt nv hc
      exact ⟨trivial,hb.closed_noLamNames_resolved _ _ _ hc.2.1,hrest.closed_noLamNames_resolved _ _ _ hc.2.2⟩
    | .guarded _ _ _ _ _ hg hb hrest =>
      intro ρ nt nv hc
      exact ⟨hg.closed_noLamNames_resolved _ _ _ hc.1,hb.closed_noLamNames_resolved _ _ _ hc.2.1,
        hrest.closed_noLamNames_resolved _ _ _ hc.2.2⟩
  termination_by structural h

  theorem HasTypeClausesQ.closed_noLamNames_resolved {P B Ψ Q C Γ Φ R eb cs t ε L}
      (h : HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t ε L) : ∀ (ρ : Nat → LocalRef) (nt nv : Nat),
      Clause.ClosedNoLamNamesList nt nv (Clause.resolveLocalsList ρ cs) →
      Clause.ClosedList nt nv (Clause.resolveLocalsList ρ cs) := by
    match h with
    | .nil =>
      intro ρ nt nv hc
      trivial
    | .cons _ _ _ _ _ hb hcs =>
      intro ρ nt nv hc
      exact ⟨hb.closed_noLamNames_resolved _ _ _ hc.1,hcs.closed_noLamNames_resolved _ _ _ hc.2⟩
  termination_by structural h

  theorem HasFailureClause.closed_noLamNames_resolved {P B Ψ Q C Γ Φ E R cs t ec L}
      (h : HasFailureClause P B Ψ Q C Γ Φ E R cs t ec L) : ∀ (ρ : Nat → LocalRef) (nt nv : Nat),
      Clause.ClosedNoLamNamesList nt nv (Clause.resolveLocalsList ρ cs) →
      Clause.ClosedList nt nv (Clause.resolveLocalsList ρ cs) := by
    match h with
    | .one _ _ _ hb =>
      intro ρ nt nv hc
      exact ⟨hc.1,hb.closed_noLamNames_resolved _ _ _ hc.2.1,trivial⟩
  termination_by structural h
end

/-- 型が付いた値では、ラムダ名の整形式を外した閉じ方から元の閉じ方を得る。 -/
theorem HasTypeVQ.closed_noLamNames {P B Ψ Q C Γ Φ v a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (nt nv : Nat) (hc : v.ClosedNoLamNames nt nv) : v.ClosedAt nt nv := by
  have hr := h.closed_noLamNames_resolved LocalRef.bound nt nv (by rw [Val.resolveLocals_id]; exact hc)
  rwa [Val.resolveLocals_id] at hr

/-- 型が付いた計算では、ラムダ名の整形式を外した閉じ方から元の閉じ方を得る。 -/
theorem HasTypeCQ.closed_noLamNames {P B Ψ Q C Γ Φ R m a e L}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) (nt nv : Nat) (hc : m.ClosedNoLamNames nt nv) : m.ClosedAt nt nv := by
  have hr := h.closed_noLamNames_resolved LocalRef.bound nt nv (by rw [Comp.resolveLocals_id]; exact hc)
  rwa [Comp.resolveLocals_id] at hr

/-- 閉包の型付けでは、ラムダ名の整形式を外した閉じ方から元の閉じ方を得る。捕捉は `CaptureOk` の Ground の前提で
閉じ、本体は解決する前の計算の型付けから得る。 -/
theorem ClosureTy.closed_noLamNames {P B Ψ S R q a e} (h : ClosureTy P B Ψ S R q a e)
    (hc : q.ClosedNoLamNames S.length) : q.ClosedAt S.length := by
  cases h with
  | mk hcap hcode _ hcode_eq _ _ _ _ _ _ _ =>
    subst hcode_eq
    exact ⟨hcap.closed,hcode.closed_noLamNames_resolved _ 0 _ hc⟩

/-- 型が付いた開始の閉包について、ラムダ名の整形式を外した閉じ方・保持値の適格性・起点の束縛から、開始の条件を
得る。名前の整形式と、捕捉値・実行時の閉包・保持した要求の閉性は、型付けが供給する。 -/
theorem StartCondition.of_typed_noLamNames {P B σ q a e}
    (hq : ClosureTy P B StoreTy.empty [] none q a e) (had : q.Adequate σ) (hc : q.ClosedNoLamNames 0)
    (hp : InitialPrepared P B σ (.run q [] Store.empty)) : StartCondition P B σ q :=
  ⟨had,hq.closed_noLamNames hc,hp⟩

/-- 空の捕捉の閉包を開始にするとき、ラムダ名の整形式を外した閉じ方・保持値の適格性・起点の束縛と、開始の計算の
型付けから、開始の条件を得る。名前の整形式は型付けが供給する。 -/
theorem StartCondition.of_noLamNames {P B σ R m a e}
    (hm : HasTypeC P B StoreTy.empty [] [] [] R m a e) (had : m.Adequate σ)
    (hc : m.ClosedNoLamNames 0 0) (hp : InitialPrepared P B σ (.run (Closure.pure m) [] Store.empty)) :
    StartCondition P B σ (Closure.pure m) :=
  ⟨⟨trivial,had⟩,⟨trivial,hm.closed_noLamNames 0 0 hc⟩,hp⟩

end Benitoite.Release.Refinement
