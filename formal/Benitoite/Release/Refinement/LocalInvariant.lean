import Benitoite.Release.Refinement.ReadLocalRefs

/-! # 型付きの実行閉包・枠・セルの専用参照 -/
namespace Benitoite.Release.Refinement
noncomputable section

/-- 捕捉元と実行コードの対応を残す。guard の本体は追加条件を持ちうる。 -/
def Closure.LocalRefs (P : Program) (B : Builtins) (Ψ : StoreTy) (depth : Nat)
    (places : Nat → Prop) (q : Closure) : Prop :=
  ∃ Γ Φ Ξ R Rs source a e L ρ ss,
    ss.length = depth ∧ CaptureOk P B Ψ R Γ Φ q.capture ∧
    HasTypeCQ P B Ψ Qempty [] (bindParams Γ ss) Ξ Rs source a e L ∧
    CaptureLocals Ψ (upSubst ss.length q.capture.env) L ρ ∧ q.code = source.resolveLocals ρ ∧
    Capture.LocalRefs P B Ψ Γ Φ q.capture ∧ Comp.LocalRefs P B Ψ depth places q.code

theorem CaptureLocals.resolved {Ψ ν L ρ depth places} (h : CaptureLocals Ψ ν L ρ)
    (hΨ : Ψ.BuilderPlaces places) : LocalCtx.Resolved L ρ depth places := by
  intro i kind hi
  obtain ⟨l,hl,ht⟩ := h i kind hi
  rw [hl]; exact hΨ _ _ ht

theorem ClosureTy.localRefs {P B Ψ ps R q a e depth places}
    (h : ClosureTy P B Ψ ps R q a e) (hn : ps.length = depth)
    (hΨ : Ψ.BuilderPlaces places) : Closure.LocalRefs P B Ψ depth places q := by
  cases h with
  | mk hc hb hl he _ _ _ _ _ _ _ =>
    simp only [List.length_map] at hn
    refine ⟨_,_,_,_,_,_,_,_,_,_,_,hn,hc,hb,hl,he,hc.localRefs,?_⟩
    rw [he]
    exact hb.localRefs (by simpa only [hn] using hl.resolved (depth := depth) hΨ) hΨ

theorem GuardBodyTy.localRefs {P B Ψ R q input a e places}
    (h : GuardBodyTy P B Ψ R q input a e) (hΨ : Ψ.BuilderPlaces places) :
    Closure.LocalRefs P B Ψ 0 places q := by
  cases h with
  | @mk cap source code Γ Φ Rs p a e L ρ hc hp hb hl he ha hr hd =>
    refine ⟨Γ,Φ,p.open (.boolean true)::Φ,R,Rs,source,a,e,L,ρ,[],rfl,hc,?_,(by simpa only [List.length_nil,upSubst_zero,Closure.capture] using hl),he,hc.localRefs,?_⟩
    · simpa only [bindParams,List.reverse_nil,List.map_nil,List.nil_append,List.length_nil,
        show Ty.shiftV 0 0 = id from funext (fun a => a.shiftV_zero 0),Option.map_id,List.map_id] using hb
    · rw [he]; exact hb.localRefs (hl.resolved hΨ) hΨ

def Frame.LocalRefs (P : Program) (B : Builtins) (Ψ : StoreTy) (places : Nat → Prop) : Frame → Prop
  | .letF q => Closure.LocalRefs P B Ψ 1 places q
  | .release v => v.NoFreeBuilders P B Ψ
  | .handleF cap cs => ∃ Γ Φ R Rs eb t e,
      CaptureOk P B (hideBuilders Ψ) R Γ Φ cap ∧ Capture.LocalRefs P B (hideBuilders Ψ) Γ Φ cap ∧
      (HasTypeClausesQ P B (hideBuilders Ψ) Qempty [] Γ Φ Rs eb cs t e [] ∨
        ∃ E, HasFailureClause P B (hideBuilders Ψ) Qempty [] Γ Φ E Rs cs t e []) ∧
      Clause.LocalRefsList P B (hideBuilders Ψ) cs
  | .guardF v cap arms _ body => ∃ Γ Φ R Rs vs t a e obs arms0 L ρ,
      CaptureOk P B Ψ R Γ Φ cap ∧ Capture.LocalRefs P B Ψ Γ Φ cap ∧
      HasTypeV P B Ψ [] Γ Φ vs t ∧ HasTypeArmsQ P B Ψ Qempty [] Γ Φ Rs obs arms0 t a e L ∧
      CaptureLocals Ψ cap.env L ρ ∧ v = closeVal cap vs ∧ arms = Arm.resolveLocalsList ρ arms0 ∧
      Arm.LocalRefsList P B Ψ 0 places arms ∧ Closure.LocalRefs P B Ψ 0 places body
  | .mark | .update _ | .drop _ => True

def Cont.LocalRefs (P : Program) (B : Builtins) (Ψ : StoreTy) (places : Nat → Prop) (k : Cont) : Prop :=
  ∀ f ∈ k, Frame.LocalRefs P B Ψ places f

theorem ContTy.localRefs {P B σ Ψ R e k a b Eb Re places}
    (h : ContTy P B σ Ψ R e k a b Eb Re) (hΨ : Ψ.BuilderPlaces places) :
    Cont.LocalRefs P B Ψ places k := by
  induction h with
  | K_Empty => intro f hf; cases hf
  | K_Let hq _ _ _ _ ih =>
    intro f hf; rcases List.mem_cons.mp hf with rfl | hf
    · exact hq.localRefs rfl hΨ
    · exact ih f hf
  | K_Mark _ _ ih | K_Update _ _ _ ih | K_Drop _ _ _ ih =>
    intro f hf; rcases List.mem_cons.mp hf with rfl | hf
    · trivial
    · exact ih f hf
  | K_Release hv _ _ _ _ ih =>
    intro f hf; rcases List.mem_cons.mp hf with rfl | hf
    · exact hv.localRefs
    · exact ih f hf
  | K_Handle hk hc hb hcap hcs hR ht hec heb ha has hr had ih =>
    intro f hf; rcases List.mem_cons.mp hf with rfl | hf
    · exact ⟨_,_,_,_,_,_,_,hcap,hcap.localRefs,Or.inl hcs,hcs.localRefs⟩
    · exact ih f hf
  | K_Handle_Fail hk hc hn hcap hcs hR ht hec hE hr hcov ha had ih =>
    intro f hf; rcases List.mem_cons.mp hf with rfl | hf
    · exact ⟨_,_,_,_,Eff.empty,_,_,hcap,hcap.localRefs,Or.inr ⟨_,hcs⟩,hcs.localRefs⟩
    · exact ih f hf
  | K_Guard hcap hv ho hs hl har hr hx hval hR ha heq hbody hsub hp hk had ih =>
    intro f hf; rcases List.mem_cons.mp hf with rfl | hf
    · refine ⟨_,_,_,_,_,_,_,_,_,_,_,_,hcap,hcap.localRefs,hv,hs,hl,hval,har,?_,hbody.localRefs hΨ⟩
      rw [har]; exact hs.localRefs (hl.resolved hΨ) hΨ
    · exact ih f hf
  | K_Sub _ _ ih => exact ih

theorem StoreOk.builder_places {P B σ Ψ μ} (h : StoreOk P B σ Ψ μ) : Ψ.BuilderPlaces (BuilderLive μ) := by
  intro l kind hl
  cases hm : μ l with
  | none => exact False.elim (h.domain l _ hl hm)
  | some c =>
    have hc := h.cell l c hm
    cases c with
    | builder contents => exact ⟨contents,hm⟩
    | val v | done v | thunk q =>
      obtain ⟨a,ha,_⟩ := hc
      rw [hl] at ha; cases ha
    | cont k =>
      obtain ⟨b,t,e,r,ha,_⟩ := hc
      rw [hl] at ha; cases ha
    | used =>
      obtain ⟨b,t,e,r,ha⟩ := hc
      rw [hl] at ha; cases ha

def Cell.LocalRefs (P : Program) (B : Builtins) (Ψ : StoreTy) (places : Nat → Prop) : Cell → Prop
  | .builder (.list vs) => Val.LocalRefsList P B Ψ 0 (fun _ => False) vs
  | .builder (.string _) | .builder (.bytes _) | .used => True
  | .val v | .done v => v.NoFreeBuilders P B Ψ
  | .thunk q => Closure.LocalRefs P B (hideBuilders Ψ) 0 (fun _ => False) q
  | .cont k => Cont.LocalRefs P B Ψ places k

theorem CellOk.localRefs {P B σ Ψ l c places} (h : CellOk P B σ Ψ l c)
    (hΨ : Ψ.BuilderPlaces places) : Cell.LocalRefs P B Ψ places c := by
  cases c with
  | builder contents =>
    obtain ⟨kind,hk,hc,had⟩ := h
    cases contents with
    | string _ | bytes _ => trivial
    | list vs =>
      cases kind with
      | string | bytes => cases hc.2
      | list a => exact hc.2.2.localRefs
  | val v | done v => obtain ⟨a,ha,hv,had⟩ := h; exact hv.localRefs
  | thunk q => obtain ⟨a,ha,hq,had⟩ := h; exact hq.localRefs rfl (StoreTy.BuilderPlaces.hidden Ψ)
  | cont k => obtain ⟨b,t,e,r,hl,he,R,et,hk⟩ := h; exact hk.localRefs hΨ
  | used => trivial

def LocalStateInvariant (P : Program) (B : Builtins) (σ : PathEnv) (s : State) : Prop :=
  ∃ Ψ, (match s with
    | .run q k μ => StoreOk P B σ Ψ μ ∧ Closure.LocalRefs P B Ψ 0 (BuilderLive μ) q ∧
        Cont.LocalRefs P B Ψ (BuilderLive μ) k ∧ ∀ l c, μ l = some c → Cell.LocalRefs P B Ψ (BuilderLive μ) c
    | .matchRun v cap arms _ k μ => StoreOk P B σ Ψ μ ∧
        (∃ vs, v = closeVal cap vs ∧ Closure.LocalRefs P B Ψ 0 (BuilderLive μ) (.mk cap (.match vs arms))) ∧
        Cont.LocalRefs P B Ψ (BuilderLive μ) k ∧ ∀ l c, μ l = some c → Cell.LocalRefs P B Ψ (BuilderLive μ) c
    | .error _ k μ | .exit _ _ k μ => StoreOk P B σ Ψ μ ∧
        Cont.LocalRefs P B Ψ (BuilderLive μ) k ∧ ∀ l c, μ l = some c → Cell.LocalRefs P B Ψ (BuilderLive μ) c) ∧
    (∀ Q C Γ Φ v a, HasTypeVQ P B Ψ Q C Γ Φ v a → v.NoFreeBuilders P B Ψ)

theorem StateTyE.local_invariant {P B σ Eb s} (h : StateTyE P B σ Eb s) : LocalStateInvariant P B σ s := by
  cases s with
  | run q k μ =>
    obtain ⟨Ψ,R,a,b,e,e1,hs,hq,he,hk,had,hcl,hkc,hμ⟩ := h
    exact ⟨Ψ,⟨hs,hq.localRefs rfl hs.builder_places,hk.localRefs hs.builder_places,
      fun l c hc => (hs.cell l c hc).localRefs hs.builder_places⟩,fun _ _ _ _ _ _ hv => hv.localRefs⟩
  | matchRun v cap arms next k μ =>
    obtain ⟨Ψ,R,a,b,e,e1,hs,⟨vs,hv,hq⟩,he,hk,had,hcap,hp,hg,har,hcl,hkc,hμ⟩ := h
    exact ⟨Ψ,⟨hs,⟨vs,hv,hq.localRefs rfl hs.builder_places⟩,hk.localRefs hs.builder_places,
      fun l c hc => (hs.cell l c hc).localRefs hs.builder_places⟩,fun _ _ _ _ _ _ hv => hv.localRefs⟩
  | error rs k μ | exit n rs k μ =>
    obtain ⟨Ψ,R,a,b,e,hs,hk,hkc,hμ⟩ := h
    exact ⟨Ψ,⟨hs,hk.localRefs hs.builder_places,fun l c hc => (hs.cell l c hc).localRefs hs.builder_places⟩,
      fun _ _ _ _ _ _ hv => hv.localRefs⟩

/-- 実行コードの専用操作に現れる場所には、指定した places が成り立つ。 -/
theorem Closure.LocalRefs.builder_location {P B Ψ q depth places kind op l args}
    (h : Closure.LocalRefs P B Ψ depth places q) (hv : q.view = .builderOp kind op (.loc l) args) : places l := by
  obtain ⟨Γ,Φ,Ξ,R,Rs,source,a,e,L,ρ,ss,hn,hc,hb,hl,he,hcap,hr⟩ := h
  cases q with
  | mk cap code =>
    cases code <;> cases hv
    cases hr with | builderOp hp _ => exact hp

theorem StateTyE.builder_live {P B σ Eb q k μ kind op l args}
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .builderOp kind op (.loc l) args) : BuilderLive μ l := by
  obtain ⟨Ψ,⟨hs,hq,hk,hcells⟩,_⟩ := h.local_invariant
  exact hq.builder_location hv

end
end Benitoite.Release.Refinement
