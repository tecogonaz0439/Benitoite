import Benitoite.Release.Refinement.SubstTyping
import Benitoite.Release.Refinement.TelTyping
import Benitoite.Release.Refinement.Step
import Benitoite.Release.Refinement.LocalResolveLemmas

/-!
# 捕捉環境を持つ継続・セル・状態の型付け

実行全体の経路環境と継続末尾の効果は添字として固定する。
場所の閉じた整形式、sort の適格性、宣言照合は別々の不変条件である。
-/
namespace Benitoite.Release.Refinement

variable {P : Program}
noncomputable section

def LocTy.Declared (P : Program) : LocTy → Prop
  | .builder (.list a) | .ref a | .lazy a => a.Declared P [] []
  | .builder _ => True
  | .cont b t e r => b.Declared P [] [] ∧ t.Declared P [] [] ∧ declaredEff P [] [] e ∧
      ∀ a, r = some a → a.Declared P [] []

def StoreTy.Declared (P : Program) (Ψ : StoreTy) : Prop := ∀ l x, Ψ l = some x → x.Declared P

theorem StoreTy.Sorted.hide {Ψ : StoreTy} (h : Ψ.Sorted) : (hideBuilders Ψ).Sorted := by
  intro l x hx
  unfold hideBuilders at hx
  cases hl : Ψ l with
  | none => simp [hl] at hx
  | some y => cases y <;> simp only [hl] at hx <;> try cases hx
              all_goals exact h _ _ hl

theorem StoreTy.Declared.hide {P : Program} {Ψ : StoreTy}
    (h : StoreTy.Declared P Ψ) : StoreTy.Declared P (hideBuilders Ψ) := by
  intro l x hx
  unfold hideBuilders at hx
  cases hl : Ψ l with
  | none => simp [hl] at hx
  | some y => cases y <;> simp only [hl] at hx <;> try cases hx
              all_goals exact h _ _ hl

def BuilderCellOk (P : Program) (B : Builtins) (Ψ : StoreTy)
    (k : BuilderKind) (c : BuilderContents) : Prop :=
  c.size ≤ (match k with | .list _ => Benitoite.Release.maxBuilderListLen | _ => Benitoite.Release.maxBuilderBytes) ∧ match k, c with
  | .string, .string _ => True
  | .bytes, .bytes bs => ∀ b ∈ bs, b ≤ 255
  | .list a, .list vs => Ty.Annotation P [] [] a ∧ HasTypeEach P B Ψ [] [] [] vs a
  | _, _ => False

/-- guard の評価前の環境と、真の条件の下の本体の導出。 -/
inductive GuardBodyTy (P : Program) (B : Builtins) (Ψ : StoreTy) (R : Option Ty) :
    Closure → Ty → Ty → Eff → Prop where
  | mk {cap code0 code Γ Φ Rs p a e L ρ} :
      CaptureOk P B Ψ R Γ Φ cap →
      Ty.Annotation P [] Γ (.refined (.base .boolean) p) →
      HasTypeCQ P B Ψ Qempty [] Γ (p.open (.boolean true) :: Φ) Rs code0 a e L →
      CaptureLocals Ψ cap.env L ρ → code = code0.resolveLocals ρ →
      Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy a) (cap.closeEff e))) →
      cap.closeR Rs = R → (∀ r, Rs = some r → r.Declared P [] Γ) →
      GuardBodyTy P B Ψ R (.mk cap code)
        (cap.closeTy (.refined (.base .boolean) p)) (cap.closeTy a) (cap.closeEff e)

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
      Ty.Annotation P [] [] a →
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
  | K_Guard {R ε v cap arms next body k a b Eb Re e1 Γ Φ Rs vs t as es arms0 L ρ obs input} :
      CaptureOk P B Ψ R Γ Φ cap →
      HasTypeV P B Ψ [] Γ Φ vs t →
      (∀ term, obs = some term → vs.toTerm? = some term ∧ ∃ sort, term.HasSort Γ sort) →
      HasTypeArmsQ P B Ψ Qempty [] Γ Φ Rs obs arms0 t as es L →
      CaptureLocals Ψ cap.env L ρ → arms = Arm.resolveLocalsList ρ arms0 →
      (∀ r, Rs = some r → Ty.Declared P [] Γ r) →
      Exhaustive P t (unguardedPats arms0) →
      v = closeVal cap vs → cap.closeR Rs = R → cap.closeTy as = a → cap.closeEff es = e1 →
      GuardBodyTy P B Ψ R body input a e1 → Eff.Sub e1 ε → MatchPrefix v arms next →
      ContTy P B σ Ψ R ε k a b Eb Re → Frame.Adequate σ (.guardF v cap arms next body) →
      ContTy P B σ Ψ none Eff.empty (.guardF v cap arms next body :: k) input b Eb Re
  | K_Sub {R ε k a a' b Eb Re} : ContTy P B σ Ψ R ε k a' b Eb Re → Ty.LeQ P [] [] a a' →
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
  (∃ n, ∀ l, n ≤ l → μ l = none) ∧ Ψ.WF ∧ Ψ.Sorted ∧ StoreTy.Declared P Ψ ∧
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
  have h0 : Ty.Declared P C [] (Refinement.shiftTypes 0 0 a) := hd.shiftTypes (TypeCtxMap.shiftEAt [] 0 0) (by intro i p hi; simp at hi)
  rw [Ty.shiftTypes_of_wf_zero hw] at h0
  have hm : ShiftMap Γ.length 0 [] Γ := ⟨by simp,by intro i a hi; cases hi⟩
  have hh := hm.declared h0
  simpa only [Ty.shiftV_of_wf_zero hw] using hh

/-- 閉じた型の sort は値文脈を任意に広げても変わらない。WF は要らない。 -/
theorem Ty.Sorted.closed_context {a : Ty} {Γ : Ctx}
    (h : a.Sorted []) : a.Sorted Γ :=
  h.context ⟨by intro i a hi; cases hi⟩

theorem Ty.WF.closed_context {a : Ty} {C : TypeCtx} {Γ : Ctx}
    (h : a.WF 0 0 0) : a.WF 0 C.length Γ.length := by
  have ht := Ty.wf_shiftTypes h C.length 0
  rw [Ty.shiftTypes_of_wf_zero h] at ht
  have hv := Ty.wf_shiftV ht Γ.length 0
  simpa only [Nat.zero_add, Ty.shiftV_of_wf_zero h] using hv

theorem Ty.Annotation.closed_context {P : Program} {a : Ty}
    {C : TypeCtx} {Γ : Ctx} (h : Ty.Annotation P [] [] a) : Ty.Annotation P C Γ a :=
  ⟨h.wf.closed_context, h.sorted.closed_context, h.declared.closed_context h.wf⟩

/-- 捕捉元の三条件から場所の型の注釈を得る。セルと有限性は要求しない。 -/
theorem StoreTy.reference_annotation {P Ψ l a C Γ}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hl : Ψ l = some (.ref a)) : Ty.Annotation P C Γ a :=
  (show Ty.Annotation P [] [] a from ⟨hw l _ hl, hs l _ hl, hd l _ hl⟩).closed_context

theorem StoreTy.lazy_annotation {P Ψ l a C Γ}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hl : Ψ l = some (.lazy a)) : Ty.Annotation P C Γ a :=
  (show Ty.Annotation P [] [] a from ⟨hw l _ hl, hs l _ hl, hd l _ hl⟩).closed_context

theorem StoreTy.cont_result_annotation {P Ψ l b t e r C Γ}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hl : Ψ l = some (.cont b t e r)) : Ty.Annotation P C Γ t :=
  (show Ty.Annotation P [] [] t from
    ⟨(hw l _ hl).2.1, (hs l _ hl).2.1, (hd l _ hl).2.1⟩).closed_context

theorem StoreTy.cont_annotation {P Ψ l b t e r}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hl : Ψ l = some (.cont b t e r)) :
    Ty.Annotation P [] [] (.dependentFn (.done t e)) :=
  ⟨⟨(hw l _ hl).2.1, (hw l _ hl).2.2.1, (hw l _ hl).2.2.2.1⟩,
    (hs l _ hl).2, (hd l _ hl).2.1, (hd l _ hl).2.2.1⟩

/-- 継続の場所の像を作る際に使う、入力・結果・潜在効果の全注釈。 -/
theorem StoreTy.cont_type_annotation {P Ψ l b t e r C Γ}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hl : Ψ l = some (.cont b t e r)) : Ty.Annotation P C Γ (.cont b t e) :=
  (show Ty.Annotation P [] [] (.cont b t e) from
    ⟨⟨(hw l _ hl).1, (hw l _ hl).2.1, (hw l _ hl).2.2.1, (hw l _ hl).2.2.2.1⟩,
      hs l _ hl, (hd l _ hl).1, (hd l _ hl).2.1, (hd l _ hl).2.2.1⟩).closed_context

theorem StoreTy.builder_list_annotation {P Ψ l a C Γ}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hl : Ψ l = some (.builder (.list a))) : Ty.Annotation P C Γ a :=
  (show Ty.Annotation P [] [] a from ⟨hw l _ hl, hs l _ hl, hd l _ hl⟩).closed_context

theorem StoreOk.finite {P B σ Ψ μ} (h : StoreOk P B σ Ψ μ) :
    ∃ n, ∀ l, n ≤ l → μ l = none := h.1

theorem StoreOk.wf {P B σ Ψ μ} (h : StoreOk P B σ Ψ μ) : Ψ.WF := h.2.1

theorem StoreOk.sorted {P B σ Ψ μ} (h : StoreOk P B σ Ψ μ) : Ψ.Sorted := h.2.2.1

theorem StoreOk.declared {P B σ Ψ μ} (h : StoreOk P B σ Ψ μ) : StoreTy.Declared P Ψ := h.2.2.2.1

theorem StoreOk.domain {P B σ Ψ μ} (h : StoreOk P B σ Ψ μ) :
    ∀ l x, Ψ l = some x → μ l ≠ none := h.2.2.2.2.1

theorem StoreOk.cell {P B σ Ψ μ} (h : StoreOk P B σ Ψ μ) :
    ∀ l c, μ l = some c → CellOk P B σ Ψ l c := h.2.2.2.2.2

theorem StoreOk.reference_annotation {P B σ Ψ μ l a C Γ} (h : StoreOk P B σ Ψ μ)
    (hl : Ψ l = some (.ref a)) : Ty.Annotation P C Γ a :=
  StoreTy.reference_annotation h.wf h.sorted h.declared hl

theorem StoreOk.lazy_annotation {P B σ Ψ μ l a C Γ} (h : StoreOk P B σ Ψ μ)
    (hl : Ψ l = some (.lazy a)) : Ty.Annotation P C Γ a :=
  StoreTy.lazy_annotation h.wf h.sorted h.declared hl

/-- 使用済みのセルも、場所の型の不変条件から結果の形成を保持する。 -/
theorem StoreOk.cont_result_annotation {P B σ Ψ μ l b t e r C Γ}
    (h : StoreOk P B σ Ψ μ) (hl : Ψ l = some (.cont b t e r)) : Ty.Annotation P C Γ t :=
  StoreTy.cont_result_annotation h.wf h.sorted h.declared hl

/-- 継続の結果と潜在効果の閉じた注釈。末尾の r の Sorted は要求しない。 -/
theorem StoreOk.cont_annotation {P B σ Ψ μ l b t e r}
    (h : StoreOk P B σ Ψ μ) (hl : Ψ l = some (.cont b t e r)) :
    Ty.Annotation P [] [] (.dependentFn (.done t e)) :=
  StoreTy.cont_annotation h.wf h.sorted h.declared hl

/-- セルが使用済みでも、不適格な sort の結果型を持つストアは受理しない。 -/
theorem StoreOk.no_unsorted_cont_result {P B σ Ψ μ l b t e r}
    (hl : Ψ l = some (.cont b t e r)) (ht : ¬ t.Sorted []) : ¬ StoreOk P B σ Ψ μ :=
  fun h => ht (h.cont_result_annotation (C := []) (Γ := []) hl).sorted

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
  (hs.cell l _ hc).val_read hl he hn

theorem StoreOk.empty (P : Program) (B : Builtins) (σ : PathEnv) :
    StoreOk P B σ StoreTy.empty Store.empty := by
  refine ⟨⟨0,by intros; rfl⟩, StoreTy.WF.empty, StoreTy.Sorted.empty, ?_, ?_, ?_⟩
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
  fun l c hc => (h.cell l c hc).adequate

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
  | K_Update _ _ _ ih => exact ih (tail he (by intro _ _ h; cases h))
  | K_Release _ _ _ _ _ ih => exact ih (tail he (by intro _ _ h; cases h))
  | K_Drop _ _ _ ih => exact ih (tail he (by intro _ _ h; cases h))
  | K_Guard _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ ih => exact ih (tail he (by intro _ _ h; cases h))

/-- StoreOk の下では、継続の場所の格納 R は再開の規則が読む正規化の等号から生の等号へ戻せる（現在の R が正規形のとき）。 -/
theorem resume_raw_return {P B σ Ψ μ l b t e r R k}
    (hs : StoreOk P B σ Ψ μ) (hl : Ψ l = some (.cont b t e r)) (hμ : μ l = some (.cont k))
    (he : r.map Ty.norm = R.map Ty.norm) (hR : ∀ x, R = some x → x.Normal) : r = R := by
  have hc := hs.cell l _ hμ
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
