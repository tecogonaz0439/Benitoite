import Benitoite.Release.Refinement.SubstTyping
import Benitoite.Release.Refinement.TelTyping
import Benitoite.Release.Refinement.Step
import Benitoite.Release.Refinement.LocalResolveLemmas

/-!
# 捕捉環境を持つ継続・セル・状態の型付け

実行全体の経路環境と継続末尾の効果は添字として固定する。
場所の閉じた整形式と宣言照合は別々の不変条件である。
-/
namespace Benitoite.Release.Refinement
noncomputable section

def LocTy.Declared (P : Program) : LocTy → Prop
  | .builder (.list a) | .ref a | .lazy a => a.Declared P [] []
  | .builder _ => True
  | .cont b t e r => b.Declared P [] [] ∧ t.Declared P [] [] ∧ declaredEff P [] [] e ∧
      ∀ a, r = some a → a.Declared P [] []

def StoreTy.Declared (P : Program) (Ψ : StoreTy) : Prop := ∀ l x, Ψ l = some x → x.Declared P

def BuilderCellOk (P : Program) (B : Builtins) (Ψ : StoreTy)
    (k : BuilderKind) (c : BuilderContents) : Prop :=
  c.size ≤ (match k with | .list _ => Benitoite.Release.maxBuilderListLen | _ => Benitoite.Release.maxBuilderBytes) ∧ match k, c with
  | .string, .string _ => True
  | .bytes, .bytes bs => ∀ b ∈ bs, b ≤ 255
  | .list a, .list vs => Ty.Annotation P [] [] a ∧ HasTypeEach P B Ψ [] [] [] vs a
  | _, _ => False

inductive ContTy (P : Program) (B : Builtins) (σ : PathEnv) (Ψ : StoreTy) :
    Option Ty → Eff → Cont → Ty → Ty → Eff → Option Ty → Prop where
  | K_Empty {R ε a Eb} : Eff.Sub ε Eb → Ty.Annotation P [] [] a →
      ContTy P B σ Ψ R ε [] a a Eb R
  | K_Let {R ε q k a c b Eb e1 Re} :
      ClosureTy P B Ψ [a] (R.map (Ty.shiftV 1 0)) q (c.shiftV 1 0) (e1.shiftV 1 0) →
      q.Adequate σ → Ty.Annotation P [] [] a → Eff.Sub e1 ε →
      ContTy P B σ Ψ R ε k c b Eb Re →
      ContTy P B σ Ψ R ε (.letF q :: k) a b Eb Re
  | K_Mark {R ε k a b Eb Re} : ContTy P B σ Ψ R ε k a b Eb Re →
      Ty.Annotation P [] [] a → ContTy P B σ Ψ (some a) ε (.mark :: k) a b Eb Re
  | K_Update {R ε l k a b Eb Re} : Ψ l = some (.lazy a) →
      ContTy P B σ Ψ R ε k a b Eb Re →
      ContTy P B σ Ψ none ε (.update l :: k) a b Eb Re
  | K_Release {R ε v o k a b Eb Re} : HasTypeV P B Ψ [] [] [] v (.opaque o (.fixed .top)) →
      v.Adequate σ → B.isResource o = true → Eff.mem ε (.name stateEff (.fixed .top)) →
      ContTy P B σ Ψ R ε k a b Eb Re →
      ContTy P B σ Ψ R ε (.release v :: k) a b Eb Re
  | K_Handle {R ε ec eb cap h k t b Eb Re Γ Φ Rs ts ecs ebs} :
      ContTy P B σ Ψ R ε k t b Eb Re → Eff.Covers [] [] ε ec → Eff.Sub eb (Eff.union ec (handled P B h)) →
      CaptureOk P B (hideBuilders Ψ) R Γ Φ cap →
      HasTypeClausesQ P B (hideBuilders Ψ) Qempty [] Γ Φ Rs ebs h ts ecs [] →
      cap.closeR Rs = R → cap.closeTy ts = t → cap.closeEff ecs = ec → cap.closeEff ebs = eb →
      Ty.Annotation P [] [] (.dependentFn (.done t ec)) →
      Ty.Annotation P [] Γ ts → (∀ a, Rs = some a → a.Declared P [] Γ) →
      Frame.Adequate σ (.handleF cap h) →
      ContTy P B σ Ψ R eb (.handleF cap h :: k) t b Eb Re
  | K_Handle_Fail {R ε ec rest E cap h k t b Eb Re Γ Φ Rs ts ecs Es} :
      ContTy P B σ Ψ R ε k t b Eb Re → Eff.Covers [] [] ε rest → NoFail Qempty rest →
      CaptureOk P B (hideBuilders Ψ) R Γ Φ cap →
      HasFailureClause P B (hideBuilders Ψ) Qempty [] Γ Φ Es Rs h ts ecs [] →
      cap.closeR Rs = R → cap.closeTy ts = t → cap.closeEff ecs = ec → cap.closeTy Es = E →
      (∀ a, Rs = some a → a.Declared P [] Γ) → Eff.Covers [] [] ε ec → Ty.Annotation P [] [] t →
      Frame.Adequate σ (.handleF cap h) →
      ContTy P B σ Ψ R (Eff.union (Eff.singleFail E) rest) (.handleF cap h :: k) t b Eb Re
  | K_Drop {R ε l k a b Eb Re b' t' e' R'} : Ψ l = some (.cont b' t' e' R') →
      (Eff.mem e' (.name stateEff (.fixed .top)) → Eff.mem ε (.name stateEff (.fixed .top))) →
      ContTy P B σ Ψ R ε k a b Eb Re →
      ContTy P B σ Ψ R ε (.drop l :: k) a b Eb Re
  | K_Guard {R ε v cap arms next body k a b Eb Re e1 Γ Φ Rs vs t as es arms0 L ρ} :
      CaptureOk P B Ψ R Γ Φ cap →
      HasTypeV P B Ψ [] Γ Φ vs t →
      HasTypeArmsQ P B Ψ Qempty [] Γ Φ Rs arms0 t as es L →
      CaptureLocals Ψ cap.env L ρ → arms = Arm.resolveLocalsList ρ arms0 →
      (∀ r, Rs = some r → Ty.Declared P [] Γ r) →
      Exhaustive P t (unguardedPats arms0) →
      v = closeVal cap vs → cap.closeR Rs = R → cap.closeTy as = a → cap.closeEff es = e1 →
      ClosureTy P B Ψ [] R body a e1 → Eff.Sub e1 ε → MatchPrefix v arms next →
      ContTy P B σ Ψ R ε k a b Eb Re → Frame.Adequate σ (.guardF v cap arms next body) →
      ContTy P B σ Ψ none Eff.empty (.guardF v cap arms next body :: k) (.base .boolean) b Eb Re
  | K_Sub {R ε k a a' b Eb Re} : ContTy P B σ Ψ R ε k a' b Eb Re → Ty.LeQ [] [] a a' →
      ContTy P B σ Ψ R ε k a b Eb Re

theorem ContTy.adequate {P B σ Ψ R ε k a b Eb Re}
    (h : ContTy P B σ Ψ R ε k a b Eb Re) : k.Adequate σ := by
  induction h <;> simp_all [Cont.Adequate, Frame.Adequate]

def EndsWithHandle (k : Cont) : Prop := ∃ k1 cap h, k = k1 ++ [.handleF cap h]

def Frame.Closed : Frame → Prop
  | .letF q => q.ClosedAt 1
  | .release v => v.Ground
  | .handleF cap h => cap.Closed ∧ Clause.ClosedList 0 cap.values.length h
  | .guardF v cap arms _ body => v.Ground ∧ cap.Closed ∧ Arm.ClosedList 0 cap.values.length arms ∧ body.ClosedAt 0
  | .mark | .update _ | .drop _ => True

def Cont.Closed (k : Cont) : Prop := ∀ f ∈ k, f.Closed

def Cell.Closed : Cell → Prop
  | .builder (.list vs) => Val.ClosedList 0 0 vs
  | .val v | .done v => v.Ground
  | .thunk q => q.ClosedAt 0
  | .cont k => k.Closed
  | .builder _ | .used => True

def Store.Closed (μ : Store) : Prop := ∀ l c, μ l = some c → c.Closed

def CellOk (P : Program) (B : Builtins) (σ : PathEnv) (Ψ : StoreTy) (l : Nat) : Cell → Prop
  | .builder c => ∃ k, Ψ l = some (.builder k) ∧ BuilderCellOk P B Ψ k c ∧ Cell.Adequate σ (.builder c)
  | .val v => ∃ a, Ψ l = some (.ref a) ∧ HasTypeV P B Ψ [] [] [] v a.norm ∧ v.Adequate σ
  | .thunk q => ∃ a, Ψ l = some (.lazy a) ∧ ClosureTy P B (hideBuilders Ψ) [] none q a Eff.empty ∧ q.Adequate σ
  | .done v => ∃ a, Ψ l = some (.lazy a) ∧ HasTypeV P B Ψ [] [] [] v a ∧ v.Adequate σ
  | .cont k => ∃ b t e r, Ψ l = some (.cont b t e r) ∧ EndsWithHandle k ∧
      ∃ R' e', ContTy P B σ Ψ R' e' k b t e r
  | .used => ∃ b t e r, Ψ l = some (.cont b t e r)

def StoreOk (P : Program) (B : Builtins) (σ : PathEnv) (Ψ : StoreTy) (μ : Store) : Prop :=
  (∃ n, ∀ l, n ≤ l → μ l = none) ∧ Ψ.WF ∧ StoreTy.Declared P Ψ ∧
  (∀ l x, Ψ l = some x → μ l ≠ none) ∧ (∀ l c, μ l = some c → CellOk P B σ Ψ l c)

def BuiltinOnly (P : Program) (B : Builtins) (e : Eff) : Prop :=
  e.fails = [] ∧ ∀ a, Eff.mem e a → ∃ l r, a = .name l r ∧ P.effects l = none ∧ (B.effects l).isSome

def StateTyE (P : Program) (B : Builtins) (σ : PathEnv) (Eb : Eff) : State → Prop
  | .run q k μ => ∃ Ψ R a b e e1, StoreOk P B σ Ψ μ ∧ ClosureTy P B Ψ [] R q a e1 ∧
      Eff.Sub e1 e ∧ ContTy P B σ Ψ R e k a b Eb none ∧ q.Adequate σ ∧ q.ClosedAt 0 ∧ k.Closed ∧ μ.Closed
  | .matchRun v cap arms next k μ => ∃ Ψ R a b e e1, StoreOk P B σ Ψ μ ∧
      (∃ vs, v = closeVal cap vs ∧ ClosureTy P B Ψ [] R (.mk cap (.match vs arms)) a e1) ∧ Eff.Sub e1 e ∧
      ContTy P B σ Ψ R e k a b Eb none ∧ v.Adequate σ ∧ cap.Adequate σ ∧
      MatchPrefix v arms next ∧ v.Ground ∧ adequateArms σ arms ∧ (cap.Closed ∧ Arm.ClosedList 0 cap.values.length arms) ∧ k.Closed ∧ μ.Closed
  | .error _ k μ | .exit _ _ k μ => ∃ Ψ R a b e, StoreOk P B σ Ψ μ ∧
      ContTy P B σ Ψ R e k a b Eb none ∧ k.Closed ∧ μ.Closed

def StateTy (P : Program) (B : Builtins) (σ : PathEnv) (s : State) : Prop :=
  σ.Valid ∧ ∃ Eb, BuiltinOnly P B Eb ∧ StateTyE P B σ Eb s


theorem Ty.Declared.closed_context {P a C Γ} (hd : Ty.Declared P [] [] a) (hw : a.WF 0 0 0) :
    Ty.Declared P C Γ a := by
  have h0 : Ty.Declared P C [] (Refinement.shiftTypes 0 0 a) := hd.shiftTypes (TypeCtxMap.shiftEAt [] 0 0)
  rw [Ty.shiftTypes_of_wf_zero hw] at h0
  have hm : ShiftMap Γ.length 0 [] Γ := ⟨by simp,by intro i a hi; cases hi⟩
  have hh := hm.declared h0
  simpa only [Ty.shiftV_of_wf_zero hw] using hh

theorem StoreOk.wf {P B σ Ψ μ} (h : StoreOk P B σ Ψ μ) : Ψ.WF := h.2.1

theorem StoreOk.declared {P B σ Ψ μ} (h : StoreOk P B σ Ψ μ) : StoreTy.Declared P Ψ := h.2.2.1

theorem StoreOk.reference_declared {P B σ Ψ μ l a C Γ} (h : StoreOk P B σ Ψ μ)
    (hl : Ψ l = some (.ref a)) : Ty.Declared P C Γ a :=
  (h.declared l _ hl).closed_context (h.wf l _ hl)

theorem StoreOk.lazy_declared {P B σ Ψ μ l a C Γ} (h : StoreOk P B σ Ψ μ)
    (hl : Ψ l = some (.lazy a)) : Ty.Declared P C Γ a :=
  (h.declared l _ hl).closed_context (h.wf l _ hl)

theorem StoreOk.cont_result_declared {P B σ Ψ μ l a b e R C Γ} (h : StoreOk P B σ Ψ μ)
    (hl : Ψ l = some (.cont a b e R)) : Ty.Declared P C Γ b :=
  (h.declared l _ hl).2.1.closed_context (h.wf l _ hl).2.1

/-- 参照の逆転が返す正規形の等号だけで、書き込む値をセルの契約へ合わせる。 -/
theorem CellOk.val_write {P B σ Ψ l a b v}
    (hl : Ψ l = some (.ref b)) (he : b.norm = a.norm) (hn : a.Normal)
    (hv : HasTypeV P B Ψ [] [] [] v a) (ha : v.Adequate σ) :
    CellOk P B σ Ψ l (.val v) := by
  refine ⟨b,hl,?_,ha⟩
  rwa [he,hn]

/-- 同じ照合で読み出しの型を得る。生の格納型の Sorted は使わない。 -/
theorem CellOk.val_read {P B σ Ψ l a b v}
    (h : CellOk P B σ Ψ l (.val v)) (hl : Ψ l = some (.ref b))
    (he : b.norm = a.norm) (hn : a.Normal) :
    HasTypeV P B Ψ [] [] [] v a := by
  obtain ⟨b',hl',hv,_⟩ := h
  rw [hl] at hl'
  cases LocTy.ref.inj (Option.some.inj hl')
  rwa [he,hn] at hv

theorem StoreOk.reference_read {P B σ Ψ μ l a b v}
    (hs : StoreOk P B σ Ψ μ) (hl : Ψ l = some (.ref b))
    (hc : μ l = some (.val v)) (he : b.norm = a.norm) (hn : a.Normal) :
    HasTypeV P B Ψ [] [] [] v a :=
  (hs.2.2.2.2 l _ hc).val_read hl he hn

theorem StoreOk.empty (P : Program) (B : Builtins) (σ : PathEnv) :
    StoreOk P B σ StoreTy.empty Store.empty := by
  refine ⟨⟨0,by intros; rfl⟩, StoreTy.WF.empty, ?_, ?_, ?_⟩
  all_goals intro l x hx; cases hx

theorem CellOk.adequate {P B σ Ψ l c} (h : CellOk P B σ Ψ l c) : c.Adequate σ := by
  cases c with
  | builder c => exact h.choose_spec.2.2
  | val v | done v => exact h.choose_spec.2.2
  | thunk q => exact h.choose_spec.2.2
  | cont k =>
    obtain ⟨b,t,e,r,_,_,R',e',hk⟩ := h
    exact hk.adequate
  | used => trivial

theorem StoreOk.adequate {P B σ Ψ μ} (h : StoreOk P B σ Ψ μ) : μ.Adequate σ :=
  fun l c hc => (h.2.2.2.2 l c hc).adequate

/-- guardの証拠は元のストアと、パターン束縛数だけ延長した局所文脈を読む。 -/
theorem HasTypeArmsQ.guard_context {P B Ψ Q C Γ Φ R arms a b e L alts guard body}
    (h : HasTypeArmsQ P B Ψ Q C Γ Φ R arms a b e L)
    (hm : Arm.mk alts (some guard) body ∈ arms) :
    ∃ δ, AltsTy P alts a δ ∧ HasTypeCQ P B Ψ Q C
      (hideConts (bindParams Γ δ)) (liftMany δ.length Φ) none guard
      (.base .boolean) Eff.empty (localExtend δ.length L) := by
  match h with
  | .nil _ => cases hm
  | .plain hp hb hs =>
    rcases List.mem_cons.mp hm with he | hh
    · cases he
    · exact hs.guard_context hh
  | .guarded (δ := δ) hp hg hb hs =>
    rcases List.mem_cons.mp hm with he | hh
    · cases he; exact ⟨δ,hp,hg⟩
    · exact hs.guard_context hh


theorem closeR_normal {cap : Capture} {R : Option Ty} {r : Ty}
    (h : cap.closeR R = some r) : r.Normal := by
  cases R with
  | none => cases h
  | some a =>
    have he : cap.closeTy a = r := Option.some.inj h
    rw [←he]; exact substTyValues_normal _ _

theorem ContTy.empty_ret {P B σ Ψ R ε k a b Eb Re}
    (h : ContTy P B σ Ψ R ε k a b Eb Re) (hk : k = []) : R = Re := by
  induction h with
  | K_Empty => rfl
  | K_Sub _ _ ih => exact ih hk
  | _ => cases hk

private theorem tail {f : Frame} {k : Cont} (he : EndsWithHandle (f :: k))
    (hf : ∀ cap h, f ≠ .handleF cap h) : EndsWithHandle k := by
  obtain ⟨k1, cap, h, hk⟩ := he
  cases k1 with
  | nil => exact absurd (List.cons.inj hk).1 (hf cap h)
  | cons g k1 => exact ⟨k1, cap, h, (List.cons.inj hk).2⟩

private theorem tail' {f : Frame} {k : Cont} (he : EndsWithHandle (f :: k)) (hk : k ≠ []) :
    EndsWithHandle k := by
  obtain ⟨k1, cap, h, hh⟩ := he
  cases k1 with
  | nil => exact absurd (List.cons.inj hh).2 hk
  | cons g k1 => exact ⟨k1, cap, h, (List.cons.inj hh).2⟩

/-- ハンドラで終わる格納の継続の末尾の R は正規形である。 -/
theorem ContTy.end_normal {P B σ Ψ R ε k a b Eb Re}
    (h : ContTy P B σ Ψ R ε k a b Eb Re) (he : EndsWithHandle k) :
    ∀ r, Re = some r → r.Normal := by
  induction h with
  | K_Empty => obtain ⟨k1,_,_,hk⟩ := he; simp at hk
  | K_Sub _ _ ih => exact ih he
  | @K_Handle R ε ec eb cap h' k t b Eb Re Γ Φ Rs ts ecs ebs ht _ _ _ _ hR _ _ _ _ _ _ _ ih =>
    by_cases hk : k = []
    · intro r hr
      have := ContTy.empty_ret ht hk
      subst this
      exact closeR_normal (hR.trans hr)
    · exact ih (tail' he hk)
  | @K_Handle_Fail R ε ec rest E cap h' k t b Eb Re Γ Φ Rs ts ecs Es ht _ _ _ _ hR _ _ _ _ _ _ _ ih =>
    by_cases hk : k = []
    · intro r hr
      have := ContTy.empty_ret ht hk
      subst this
      exact closeR_normal (hR.trans hr)
    · exact ih (tail' he hk)
  | K_Let _ _ _ _ _ ih => exact ih (tail he (by intro _ _ h; cases h))
  | K_Mark _ _ ih => exact ih (tail he (by intro _ _ h; cases h))
  | K_Update _ _ ih => exact ih (tail he (by intro _ _ h; cases h))
  | K_Release _ _ _ _ _ ih => exact ih (tail he (by intro _ _ h; cases h))
  | K_Drop _ _ _ ih => exact ih (tail he (by intro _ _ h; cases h))
  | K_Guard _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ ih => exact ih (tail he (by intro _ _ h; cases h))

/-- StoreOk の下では、継続の場所の格納 R は再開の規則が読む正規化の等号から生の等号へ戻せる（現在の R が正規形のとき）。 -/
theorem resume_raw_return {P B σ Ψ μ l b t e r R k}
    (hs : StoreOk P B σ Ψ μ) (hl : Ψ l = some (.cont b t e r)) (hμ : μ l = some (.cont k))
    (he : r.map Ty.norm = R.map Ty.norm) (hR : ∀ x, R = some x → x.Normal) : r = R := by
  have hc := hs.2.2.2.2 l _ hμ
  obtain ⟨b',t',e',r',hl',hend,_,_,hk⟩ := hc
  rw [hl] at hl'
  cases Option.some.inj hl'
  have hn := ContTy.end_normal hk hend
  cases r with
  | none => cases R <;> simp_all
  | some x =>
    cases R with
    | none => simp at he
    | some y =>
      have h1 : x.norm = x := hn x rfl
      have h2 : y.norm = y := hR y rfl
      have h3 : x.norm = y.norm := Option.some.inj he
      rw [h1, h2] at h3
      rw [h3]


end
end Benitoite.Release.Refinement
