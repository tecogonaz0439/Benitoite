import Benitoite.Release.Refinement.SafeCheckErasure

/-! # 消去した計算・継続・ストアの対応 -/
namespace Benitoite.Release.Refinement.SafeCheckErasure
noncomputable section
open CheckErasure RefinementCheck

/-- 両側で同じ閉包を使う場合の対応。 -/
theorem ClosureRel.refl (q : Closure) : ClosureRel q q := by cases q; exact .code (.same _)

theorem ClosureRel.apply {q q'} (h : ClosureRel q q') (vs : List Val) :
    ClosureRel (q.apply vs) (q'.apply vs) := by
  cases h with
  | code h => exact .code h
  | returned h => exact .returned h
/-- 消した結果の値は、どの捕捉でも同じ値になる。 -/
theorem Site.result_static {t u v} (h : Site t u v) (cap : Capture) : closeVal cap (ok u v) = ok u v :=
  Comp.ret.inj (h.stable.view cap).2

theorem Arms.refl (as : List Arm) : Arms as as := by
  induction as with
  | nil => exact .nil
  | cons a as ih => cases a with
    | mk alts guard body => cases guard with
      | none => exact .plain (.same _) ih
      | some g => exact .guard (.same _) (.same _) ih

theorem Clauses.refl (cs : List Clause) : Clauses cs cs := by
  induction cs with
  | nil => exact .nil
  | cons c cs ih => cases c with
    | mk o a nt m => exact .op (.same _) ih
    | fail e m => exact .fail (.same _) ih

theorem FrameRel.refl (f : Frame) : FrameRel f f := by
  cases f with
  | letF q => exact .letF (.refl _)
  | mark => exact .mark
  | update l => exact .update _
  | release v => exact .release _
  | handleF cap cs => exact .handleF (.refl _)
  | drop l => exact .drop _
  | guardF v cap as n q => exact .guardF (.refl _) (.refl _)

theorem ContRel.refl (k : Cont) : ContRel k k := by
  induction k with
  | nil => exact .nil
  | cons f k ih => exact .cons (.refl _) ih

theorem ContRel.append {k l k' l'} (h : ContRel k l) (g : ContRel k' l') : ContRel (k ++ k') (l ++ l') := by
  induction h with
  | nil => exact g
  | cons h _ ih => exact .cons h ih

theorem ContRel.markPush {k l} (h : ContRel k l) : ContRel (markPush k) (markPush l) := by
  cases h with
  | nil => exact .cons .mark .nil
  | cons hf hk => cases hf <;> first | exact .cons .mark hk | exact .cons .mark (.cons (by constructor <;> assumption) hk)

theorem ContRel.releases {k l} (h : ContRel k l) : ContRel (releases k) (releases l) := by
  induction h with
  | nil => exact .nil
  | cons hf _ ih => cases hf <;> first | exact ih | exact .cons (by constructor) ih

theorem CellRel.refl (c : Cell) : CellRel c c := by
  cases c with
  | builder c => exact .builder _
  | val v => exact .value _
  | done v => exact .done _
  | used => exact .used
  | thunk q => exact .thunk (.refl _)
  | cont k => exact .cont (.refl _)

theorem StoreRel.refl (μ : Store) : StoreRel μ μ := by
  intro l
  cases h : μ l with
  | none => exact .none
  | some c => exact .some (.refl _)

theorem StoreRel.set {μ ν l c d} (h : StoreRel μ ν) (g : CellRel c d) :
    StoreRel (μ.set l c) (ν.set l d) := by
  intro x
  by_cases hx : x = l
  · subst x; simpa only [Store.set,ite_true] using (Option.Rel.some g)
  · simpa only [Store.set,hx,ite_false] using h x

theorem StoreRel.none {μ ν l} (h : StoreRel μ ν) (e : μ l = none) : ν l = none := by
  have hr := h l
  rw [e] at hr
  cases ho : ν l with
  | none => rfl
  | some c => rw [ho] at hr; cases hr

theorem StoreRel.some {μ ν l c} (h : StoreRel μ ν) (e : μ l = some c) :
    ∃ d, ν l = some d ∧ CellRel c d := by
  have hr := h l
  rw [e] at hr
  cases ho : ν l with
  | none => rw [ho] at hr; cases hr
  | some d =>
    rw [ho] at hr
    cases hr with
    | some hc => exact ⟨d,rfl,hc⟩

/-- 対応する腕は、パターンとガードの有無を保つ。 -/
theorem Arms.get {as bs : List Arm} (h : Arms as bs) {i : Nat} {alts : List Alt} {guard : Option Comp} {body : Comp}
    (hg : as[i]? = some (.mk alts guard body)) :
    ∃ guard' body', bs[i]? = some (.mk alts guard' body') ∧ Code body body' ∧ Option.Rel Code guard guard' := by
  cases h with
  | nil => simp at hg
  | plain h g =>
    cases i with
    | zero => cases hg; exact ⟨_,_,rfl,h,.none⟩
    | succ i => exact g.get hg
  | guard h g k =>
    cases i with
    | zero => cases hg; exact ⟨_,_,rfl,g,.some h⟩
    | succ i => exact k.get hg

/-- 節の処理する操作とその順は保たれる。 -/
theorem Clauses.handles {cs ds} (h : Clauses cs ds) (o : OpRef) : handles cs o = handles ds o := by
  cases h with
  | nil => rfl
  | op _ h => exact congrArg (fun b => _ || b) (h.handles o)
  | fail _ h => exact congrArg (fun b => _ || b) (h.handles o)

/-- 節を検索した結果は、同じ操作・入力数・型数の節になる。 -/
theorem Clauses.find {cs ds} (h : Clauses cs ds) (o : OpRef) {c}
    (hc : findClause cs o = some c) :
    ∃ d, findClause ds o = some d ∧ Clauses [c] [d] := by
  cases h with
  | nil => simp [findClause] at hc
  | op h g =>
    simp only [findClause,List.find?_cons,Clause.op] at hc ⊢
    split at hc
    · next hp => cases hc; exact ⟨_,rfl,.op h .nil⟩
    · next hp => exact g.find o hc
  | fail h g =>
    simp only [findClause,List.find?_cons,Clause.op] at hc ⊢
    split at hc
    · next hp => cases hc; exact ⟨_,rfl,.fail h .nil⟩
    · next hp => exact g.find o hc
/-- 対応は、現在実行する値を閉じた view にも成り立つ。 -/
theorem ClosureRel.view {q q'} (h : ClosureRel q q') : Code q.view q'.view := by
  cases h with
  | @returned cap cap' v h => simpa only [Closure.view,Closure.code,Closure.capture,h] using Code.same (.ret v)
  | code h =>
    cases h with
    | same m => exact .same _
    | check h => rw [(h.stable.view _).1,(h.stable.view _).2]; exact .check h
    | builder h => exact .builder h
    | letIn h g => exact .letIn h g
    | ite h g => exact .ite h g
    | matchC h => exact .matchC h
    | lazyC h => exact .lazyC h
    | use h => exact .use h
    | handle h g => exact .handle h g

/-- return 以外で次の本体を作るとき、両側の捕捉は同じである。 -/
theorem ClosureRel.capture {q q'} (h : ClosureRel q q') :
    q.capture = q'.capture ∨ ∃ v, q.view = .ret v ∧ q'.view = .ret v := by
  cases h with
  | code _ => exact Or.inl rfl
  | @returned cap cap' v h => exact Or.inr ⟨v,by simp [Closure.view,Closure.capture,Closure.code,h],by simp [Closure.view,Closure.capture,Closure.code,h]⟩

theorem Code.ret_inv {v n} (h : Code (.ret v) n) : n = .ret v := by cases h; rfl

theorem Code.escape_inv {v n} (h : Code (.escape v) n) : n = .escape v := by cases h; rfl

theorem Code.app_inv {f vs n} (h : Code (.app f vs) n) :
    n = .app f vs ∨ ∃ t u v, f = .prim PublicNames.checkName [t,u] [] [] ∧ vs = [v] ∧
      n = .ret (ok u v) ∧ Site t u v := by
  cases h with
  | same _ => exact Or.inl rfl
  | check h => exact Or.inr ⟨_,_,_,rfl,rfl,rfl,h⟩

theorem Code.builder_inv {k m n} (h : Code (.builderLet k m) n) :
    ∃ m', n = .builderLet k m' ∧ Code m m' := by
  cases h with
  | same _ => exact ⟨_,rfl,.same _⟩
  | builder h => exact ⟨_,rfl,h⟩

theorem Code.let_inv {m n z} (h : Code (.letIn m n) z) :
    ∃ m' n', z = .letIn m' n' ∧ Code m m' ∧ Code n n' := by
  cases h with
  | same _ => exact ⟨_,_,rfl,.same _,.same _⟩
  | letIn h g => exact ⟨_,_,rfl,h,g⟩

theorem Code.ite_inv {v m n z} (h : Code (.ite v m n) z) :
    ∃ m' n', z = .ite v m' n' ∧ Code m m' ∧ Code n n' := by
  cases h with
  | same _ => exact ⟨_,_,rfl,.same _,.same _⟩
  | ite h g => exact ⟨_,_,rfl,h,g⟩

theorem Code.match_inv {v as z} (h : Code (.match v as) z) :
    ∃ bs, z = .match v bs ∧ Arms as bs := by
  cases h with
  | same _ => exact ⟨_,rfl,.refl _⟩
  | matchC h => exact ⟨_,rfl,h⟩

theorem Code.lazy_inv {m z} (h : Code (.lazyC m) z) :
    ∃ n, z = .lazyC n ∧ Code m n := by
  cases h with
  | same _ => exact ⟨_,rfl,.same _⟩
  | lazyC h => exact ⟨_,rfl,h⟩

theorem Code.use_inv {v m z} (h : Code (.use v m) z) :
    ∃ n, z = .use v n ∧ Code m n := by
  cases h with
  | same _ => exact ⟨_,rfl,.same _⟩
  | use h => exact ⟨_,rfl,h⟩

theorem Code.handle_inv {m cs z} (h : Code (.handle m cs) z) :
    ∃ n ds, z = .handle n ds ∧ Code m n ∧ Clauses cs ds := by
  cases h with
  | same _ => exact ⟨_,_,rfl,.same _,.refl _⟩
  | handle h g => exact ⟨_,_,rfl,h,g⟩

/-- 消去の根以外で、値だけを読む各計算は同じ計算を読む。 -/
theorem Code.atomic_inv {m n} (h : Code m n)
    (ha : (∀ k x, m ≠ .builderLet k x) ∧ (∀ x y, m ≠ .letIn x y) ∧
      (∀ f vs, m ≠ .app f vs) ∧ (∀ v x y, m ≠ .ite v x y) ∧
      (∀ v as, m ≠ .match v as) ∧ (∀ x, m ≠ .lazyC x) ∧
      (∀ v x, m ≠ .use v x) ∧ (∀ x cs, m ≠ .handle x cs)) : n = m := by
  cases h with
  | same _ => rfl
  | check _ => exact (ha.2.2.1 _ _ rfl).elim
  | builder _ => exact (ha.1 _ _ rfl).elim
  | letIn _ _ => exact (ha.2.1 _ _ rfl).elim
  | ite _ _ => exact (ha.2.2.2.1 _ _ _ rfl).elim
  | matchC _ => exact (ha.2.2.2.2.1 _ _ rfl).elim
  | lazyC _ => exact (ha.2.2.2.2.2.1 _ rfl).elim
  | use _ => exact (ha.2.2.2.2.2.2.1 _ _ rfl).elim
  | handle _ _ => exact (ha.2.2.2.2.2.2.2 _ _ rfl).elim

/-- 現在の成功した検査の署名と応答。完成した標準表の行から供給する。 -/
structure Agreement (B : Builtins) : Prop where
  signature : B.sig PublicNames.checkName = some RefinementCheck.signature
  delta : ∀ t u v, B.delta PublicNames.checkName [t,u] [] [] [v] =
    RefinementCheck.delta StandardModel.checkExpectedText PublicNames.checkName [t,u] [] [] [v]

/-- 成功した根の検査は、同じ値を返す事象なしの一段だけを省く。 -/
theorem root_step {P B σ q cap' k k' μ μ' t u v label dest}
    (ha : Agreement B) (site : Site t u v)
    (hq : q.view = call t u v)
    (hk : ContRel k k') (hm : StoreRel μ μ')
    (step : Step P B σ (.run q k μ) label dest) :
    label = none ∧ StateRel dest (.run (.mk cap' (.ret (ok u v))) k' μ') := by
  have unique := CheckErasure.step_unique hq ha.signature (ha.delta t u v)
    (site.stable.view Capture.empty).1 site.normalSource site.normalExpected site.core site.accepts step
  obtain ⟨rfl,rfl⟩ := unique
  rw [CheckErasure.erase_check (site.stable.view Capture.empty).1 site.normalSource site.normalExpected site.core site.accepts]
  -- 根の view が return と一致する閉包は、以後の同じ継続の実行を共有する。
  exact ⟨rfl, .run (.returned (site.result_static)) hk hm⟩
/-- 呼出しの view は、そのままか、成功した検査の結果のどちらかである。 -/
theorem ClosureRel.app {q q' f vs} (h : ClosureRel q q') (hv : q.view = .app f vs) :
    q'.view = .app f vs ∨ ∃ t u v cap, Site t u v ∧ q.view = call t u v ∧ q' = .mk cap (.ret (ok u v)) := by
  cases h with
  | returned h => simp [Closure.view,Closure.code,Closure.capture,h] at hv
  | code h =>
    cases h with
    | same m => exact Or.inl hv
    | check h => exact Or.inr ⟨_,_,_,_,h,(h.stable.view _).1,rfl⟩
    | _ => simp [Closure.view,Closure.code,Closure.capture] at hv

/-- return 以外の計算の捕捉は同じである。 -/
theorem ClosureRel.capture_eq {q q'} (h : ClosureRel q q') (hn : ∀ v, q.view ≠ .ret v) : q.capture = q'.capture := by
  rcases h.capture with he | ⟨v,hv,_⟩
  · exact he
  · exact (hn v hv).elim

theorem ContRel.mem_right {k l} (h : ContRel k l) {g} (hg : g ∈ l) : ∃ f ∈ k, FrameRel f g := by
  induction h with
  | nil => cases hg
  | cons hf _ ih =>
    rcases List.mem_cons.mp hg with rfl | hg
    · exact ⟨_,List.mem_cons_self,hf⟩
    · obtain ⟨f,hf,hrel⟩ := ih hg; exact ⟨f,List.mem_cons_of_mem _ hf,hrel⟩

theorem ContRel.noHandler {k l} (h : ContRel k l) {o} (hn : NoHandler k o) : NoHandler l o := by
  intro cap cs hm
  obtain ⟨f,hf,hr⟩ := h.mem_right hm
  cases hr with
  | handleF hc => rw [← hc.handles o]; exact hn _ _ hf

/-- ハンドラを見付ける分割を、対応する継続の同じ位置へ移す。 -/
theorem ContRel.split {k l} (h : ContRel k l) {k1 cap cs k2}
    (he : k = k1 ++ .handleF cap cs :: k2) :
    ∃ l1 ds l2, l = l1 ++ .handleF cap ds :: l2 ∧ ContRel k1 l1 ∧ Clauses cs ds ∧ ContRel k2 l2 := by
  subst k
  induction k1 generalizing l with
  | nil =>
    cases h with
    | cons hf hk => cases hf with
      | handleF hc => exact ⟨[],_,_,rfl,.nil,hc,hk⟩
  | cons f k1 ih =>
    cases h with
    | cons hf hk =>
      obtain ⟨l1,ds,l2,he,h1,hc,h2⟩ := ih hk
      subst he
      exact ⟨_ :: l1,ds,l2,rfl,.cons hf h1,hc,h2⟩

theorem ContRel.splitAt {k l k1 cap cs k2 o} (h : ContRel k l) (hs : SplitAt o k k1 cap cs k2) :
    ∃ l1 ds l2, SplitAt o l l1 cap ds l2 ∧ ContRel k1 l1 ∧ Clauses cs ds ∧ ContRel k2 l2 := by
  obtain ⟨l1,ds,l2,he,h1,hc,h2⟩ := h.split hs.1
  exact ⟨l1,ds,l2,⟨he,(hc.handles o) ▸ hs.2.1,h1.noHandler hs.2.2⟩,h1,hc,h2⟩

/-- 定義の本体の書換えは、辞書の上位射影を変えない。 -/
theorem superStep_program (P : Program) (v : Val) : v.superStep (eraseProgram P) = v.superStep P := by
  cases v with
  | super v s =>
    cases v <;> first | rfl | (simp only [Val.superStep]; rw [superStep_program])
  | _ => rfl
termination_by structural v

/-- At の実行が読むコードと捕捉は保持する。 -/
theorem ClosureRel.checkAt {q q' k o sh bs p v ix} (h : ClosureRel q q')
    (hv : q.code = .checkAt k o sh bs p v ix) :
    q'.code = .checkAt k o sh bs p v ix ∧ q.capture = q'.capture := by
  cases h with
  | code h =>
    simp only [Closure.code] at hv
    exact ⟨(hv ▸ h).atomic_inv (by simp),rfl⟩
  | returned _ => cases hv

mutual
  theorem externalCheck_program (P : Program) (v : Val) (a : Ty) :
      externalCheck (eraseProgram P) v a = externalCheck P v a := by
    cases a with
    | refined a p => simp only [externalCheck,externalCheck_program P v a]
    | list a => cases v <;> simp only [externalCheck] <;> exact externalCheckEach_program P _ a
    | set a => cases v <;> simp only [externalCheck] <;> exact externalCheckEach_program P _ a
    | map a b =>
      cases v <;> simp only [externalCheck]
      case mapV ks vs => rw [externalCheckEach_program P ks a,externalCheckEach_program P vs b]
    | data d ts =>
      cases v <;> simp only [externalCheck]
      case con c tys vs =>
        simp only [eraseProgram]
        cases hc : P.cons c with
        | none => rfl
        | some cd =>
          exact congrArg (fun b => decide (cd.data = d ∧ cd.ntys = ts.length) && b)
            (externalCheckFields_program P vs (cd.args.map (Ty.subst ts [])))
    | _ => cases v <;> simp only [externalCheck]
  termination_by (sizeOf v,sizeOf a)
  theorem externalCheckEach_program (P : Program) (vs : List Val) (a : Ty) :
      externalCheckEach (eraseProgram P) vs a = externalCheckEach P vs a := by
    cases vs with
    | nil => simp only [externalCheckEach]
    | cons v vs =>
      simp only [externalCheckEach]
      rw [externalCheck_program P v a,externalCheckEach_program P vs a]
  termination_by (sizeOf vs,sizeOf a)
  theorem externalCheckFields_program (P : Program) (vs : List Val) (as : List Ty) :
      externalCheckFields (eraseProgram P) vs as = externalCheckFields P vs as := by
    cases vs with
    | nil => cases as <;> simp only [externalCheckFields]
    | cons v vs => cases as with
      | nil => simp only [externalCheckFields]
      | cons a as =>
        simp only [externalCheckFields]
        rw [externalCheck_program P v a,externalCheckFields_program P vs as]
  termination_by (sizeOf vs,sizeOf as)
end

/-- 外部の受信検査は、定義の本体の消去で変わらない。 -/
theorem externalReceive_program (P : Program) (d : ExternalSignature) (ts : List Ty) (vs : List Val) (out : Outcome) :
    externalReceive (eraseProgram P) d ts vs out = externalReceive P d ts vs out := by
  unfold externalReceive
  congr 1
  funext pair
  cases out <;> simp only [externalCheckedOutcome,externalCheck_program]

theorem Clauses.single_body {c d : Clause} (h : Clauses [c] [d]) : Code c.body d.body := by
  cases h <;> assumption

/-- 省略する根の検査の段では 1 から 0 へ減る。 -/
def silentRank : State → Nat
  | .run q _ _ => match q.view with | .app _ _ => 1 | _ => 0
  | _ => 0

theorem root_rank {P B σ q k μ t u v label dest} (ha : Agreement B) (site : Site t u v)
    (hq : q.view = call t u v) (step : Step P B σ (.run q k μ) label dest) :
    silentRank dest < silentRank (.run q k μ) := by
  obtain ⟨_,rfl⟩ := CheckErasure.step_unique hq ha.signature (ha.delta t u v)
    (site.stable.view Capture.empty).1 site.normalSource site.normalExpected site.core site.accepts step
  rw [CheckErasure.erase_check (site.stable.view Capture.empty).1 site.normalSource site.normalExpected site.core site.accepts]
  simp only [silentRank,hq,call]
  simp [Closure.pure,Closure.view,Closure.code,Closure.capture]

/-- 対応する状態からの一段を、一段又は検査の事象なしの省略で対応させる。 -/
def Matches (P : Program) (B : Builtins) (σ : PathEnv) (s t : State) (label : Option Event) (s' : State) : Prop :=
  ∃ t', (Step (eraseProgram P) B σ t label t' ∨ (label = none ∧ t' = t ∧ silentRank s' < silentRank s)) ∧ StateRel s' t'

/-- 現在実行する閉包の一段についての模倣。 -/
theorem run_step {P B σ q q' k k' μ μ' label dest}
    (ha : Agreement B) (hq : ClosureRel q q') (hk : ContRel k k') (hm : StoreRel μ μ')
    (hs : Step P B σ (.run q k μ) label dest) : Matches P B σ (.run q k μ) (.run q' k' μ') label dest := by
  classical
  by_cases root : ∃ t u v cap, Site t u v ∧ q.view = call t u v ∧ q' = .mk cap (.ret (ok u v))
  · obtain ⟨t,u,v,cap,site,hview,rfl⟩ := root
    obtain ⟨hl,hr⟩ := root_step ha site hview hk hm hs
    exact ⟨_,Or.inr ⟨hl,rfl,root_rank ha site hview hs⟩,hr⟩
  have app : ∀ f vs, q.view = .app f vs → q'.view = .app f vs := by
    intro f vs hv
    exact (hq.app hv).resolve_right root
  have cap : (∀ v, q.view ≠ .ret v) → q.capture = q'.capture := hq.capture_eq
  cases hs with
  | E_Let hv =>
    obtain ⟨m,n,ht,h1,h2⟩ := (hv ▸ hq.view).let_inv
    have hc := cap (by intro v h; rw [hv] at h; cases h)
    refine ⟨_,Or.inl (.E_Let ht),.run ?_ (.cons (.letF ?_) hk) hm⟩
    · simpa only [hc] using (ClosureRel.code h1)
    · simpa only [hc] using (ClosureRel.code h2)
  | E_IfT hv =>
    obtain ⟨m,n,ht,h1,_⟩ := (hv ▸ hq.view).ite_inv
    have hc := cap (by intro v h; rw [hv] at h; cases h)
    exact ⟨_,Or.inl (.E_IfT ht),.run (by simpa only [hc] using ClosureRel.code h1) hk hm⟩
  | E_IfF hv =>
    obtain ⟨m,n,ht,_,h2⟩ := (hv ▸ hq.view).ite_inv
    have hc := cap (by intro v h; rw [hv] at h; cases h)
    exact ⟨_,Or.inl (.E_IfF ht),.run (by simpa only [hc] using ClosureRel.code h2) hk hm⟩
  | E_Match hv =>
    obtain ⟨as,ht,harms⟩ := (hv ▸ hq.view).match_inv
    have hc := cap (by intro v h; rw [hv] at h; cases h)
    exact ⟨_,Or.inl (.E_Match ht),by simpa only [hc] using StateRel.matchRun harms hk hm⟩
  | E_Handle hv =>
    obtain ⟨m,cs,ht,hbody,hcs⟩ := (hv ▸ hq.view).handle_inv
    have hc := cap (by intro v h; rw [hv] at h; cases h)
    refine ⟨_,Or.inl (.E_Handle ht),?_⟩
    simpa only [hc] using StateRel.run (.code hbody) (.cons (.handleF hcs) hk) hm
  | E_Use hv =>
    obtain ⟨m,ht,hbody⟩ := (hv ▸ hq.view).use_inv
    have hc := cap (by intro v h; rw [hv] at h; cases h)
    exact ⟨_,Or.inl (.E_Use ht),.run (by simpa only [hc] using ClosureRel.code hbody) (.cons (.release _) hk) hm⟩
  | E_Prim hv sig kind delta =>
    exact ⟨_,Or.inl (.E_Prim (app _ _ hv) sig kind delta),.run (.refl _) hk hm⟩
  | E_Err hv sig kind delta =>
    exact ⟨_,Or.inl (.E_Err (app _ _ hv) sig kind delta),.error hk hm⟩
  | E_Lam hv closed arity =>
    exact ⟨_,Or.inl (.E_Lam (app _ _ hv) closed arity),.run (.refl _) hk.markPush hm⟩
  | E_ExternalApply hv =>
    exact ⟨_,Or.inl (.E_ExternalApply (app _ _ hv)),.run (.refl _) hk hm⟩
  | E_PathBasesApply hv sig kind =>
    have hc := cap (by intro v h; rw [hv] at h; cases h)
    exact ⟨_,Or.inl (.E_PathBasesApply (app _ _ hv) sig kind),.run (by simpa only [hc] using ClosureRel.code (.same _)) hk hm⟩
  | E_RefNew hv sig kind fresh =>
    exact ⟨_,Or.inl (.E_RefNew (app _ _ hv) sig kind (hm.none fresh)),.run (.refl _) hk (hm.set (.value _))⟩
  | E_RefSet hv sig kind =>
    exact ⟨_,Or.inl (.E_RefSet (app _ _ hv) sig kind),.run (.refl _) hk (hm.set (.value _))⟩
  | E_RefUpdate hv sig kind =>
    exact ⟨_,Or.inl (.E_RefUpdate (app _ _ hv) sig kind),.run (.refl _) hk hm⟩
  | @E_Fun f ts es rs ws _ _ d _ hv hd hws hts hes =>
    have hd' : (eraseProgram P).defs f = some { d with body := erase d.body } := by simp [eraseProgram,hd]
    refine ⟨_,Or.inl (.E_Fun (app _ _ hv) hd' hws hts hes),.run (.code ?_) hk.markPush hm⟩
    exact (erase_code _).instR _ |>.substTy 0 _ _
  | E_BuilderNew hv fresh =>
    obtain ⟨m,ht,hbody⟩ := (hv ▸ hq.view).builder_inv
    have hc := cap (by intro v h; rw [hv] at h; cases h)
    refine ⟨_,Or.inl (.E_BuilderNew ht (hm.none fresh)),.run ?_ hk (hm.set (.builder _))⟩
    simpa only [hc] using ClosureRel.code (hbody.subst builderValueSubst _)
  | E_BuilderOp hv cell result =>
    have ht := (hv ▸ hq.view).atomic_inv (by simp)
    obtain ⟨c,hcell,hc⟩ := hm.some cell
    cases hc
    exact ⟨_,Or.inl (.E_BuilderOp ht hcell result),.run (.refl _) hk (hm.set (.builder _))⟩
  | E_BuilderErr hv cell result =>
    have ht := (hv ▸ hq.view).atomic_inv (by simp)
    obtain ⟨c,hcell,hc⟩ := hm.some cell
    cases hc
    exact ⟨_,Or.inl (.E_BuilderErr ht hcell result),.error hk hm⟩
  | E_Return hv =>
    have ht := (hv ▸ hq.view).ret_inv
    cases hk with
    | cons hf hk => cases hf with
      | letF hr => exact ⟨_,Or.inl (.E_Return ht),.run (hr.apply _) hk hm⟩
  | E_External hv decl response receive =>
    have ht := (hv ▸ hq.view).atomic_inv (by simp)
    exact ⟨_,Or.inl (.E_External ht decl response (by rwa [externalReceive_program])),.run (.refl _) hk hm⟩
  | E_ExternalErr hv decl response receive =>
    have ht := (hv ▸ hq.view).atomic_inv (by simp)
    exact ⟨_,Or.inl (.E_ExternalErr ht decl response (by rwa [externalReceive_program])),.error hk hm⟩
  | E_IssuePathBases hv sig kind hop valid =>
    have ht := (hv ▸ hq.view).atomic_inv (by simp)
    exact ⟨_,Or.inl (.E_IssuePathBases ht sig kind hop valid),.run (.refl _) hk hm⟩
  | E_AtOk hv prepare shape check =>
    obtain ⟨ht,hc⟩ := hq.checkAt hv
    refine ⟨_,Or.inl (.E_AtOk ht (hc ▸ prepare) shape check),.run ?_ hk hm⟩
    simpa only [hc] using ClosureRel.refl _
  | E_AtError hv prepare shape check =>
    obtain ⟨ht,hc⟩ := hq.checkAt hv
    refine ⟨_,Or.inl (.E_AtError ht (hc ▸ prepare) shape check),.run ?_ hk hm⟩
    simpa only [hc] using ClosureRel.refl _
  | E_AtPrepareError hv prepare =>
    obtain ⟨ht,hc⟩ := hq.checkAt hv
    refine ⟨_,Or.inl (.E_AtPrepareError ht (hc ▸ prepare)),.run ?_ hk hm⟩
    simpa only [hc] using ClosureRel.refl _
  | E_Meth hv id body cd ms hw hvlen ht hs he =>
    have hview := (hv ▸ hq.view).atomic_inv (by simp)
    exact ⟨_,Or.inl (.E_Meth hview id body cd ms hw hvlen ht hs he),.run (.refl _) hk.markPush hm⟩
  | E_Super hv step =>
    have ht := (hv ▸ hq.view).atomic_inv (by simp)
    exact ⟨_,Or.inl (.E_Super ht (by rwa [superStep_program])),.run (.refl _) hk hm⟩
  | E_GuardT hv =>
    have ht := (hv ▸ hq.view).ret_inv
    cases hk with
    | cons hf hk => cases hf with
      | guardF ha hb => exact ⟨_,Or.inl (.E_GuardT ht),.run hb hk hm⟩
  | E_GuardF hv =>
    have ht := (hv ▸ hq.view).ret_inv
    cases hk with
    | cons hf hk => cases hf with
      | guardF ha hb => exact ⟨_,Or.inl (.E_GuardF ht),.matchRun ha hk hm⟩
  | E_IO hv sig kind handler response =>
    exact ⟨_,Or.inl (.E_IO (app _ _ hv) sig kind (hk.noHandler handler) response),.run (.refl _) hk hm⟩
  | E_IOErr hv sig kind handler response =>
    exact ⟨_,Or.inl (.E_IOErr (app _ _ hv) sig kind (hk.noHandler handler) response),.error hk hm⟩
  | E_Exit hv sig kind handler response =>
    exact ⟨_,Or.inl (.E_Exit (app _ _ hv) sig kind (hk.noHandler handler) response),.exit hk hm⟩
  | E_RefGet hv sig kind cell =>
    obtain ⟨c,hcell,hc⟩ := hm.some cell
    cases hc
    exact ⟨_,Or.inl (.E_RefGet (app _ _ hv) sig kind hcell),.run (.refl _) hk hm⟩
  | E_Lazy hv fresh =>
    obtain ⟨m,ht,hbody⟩ := (hv ▸ hq.view).lazy_inv
    have hc := cap (by intro v h; rw [hv] at h; cases h)
    refine ⟨_,Or.inl (.E_Lazy ht (hm.none fresh)),.run (.refl _) hk (hm.set (.thunk ?_))⟩
    simpa only [hc] using ClosureRel.code hbody
  | E_ForceDone hv sig kind cell =>
    obtain ⟨c,hcell,hc⟩ := hm.some cell
    cases hc
    exact ⟨_,Or.inl (.E_ForceDone (app _ _ hv) sig kind hcell),.run (.refl _) hk hm⟩
  | E_Force hv sig kind cell =>
    obtain ⟨c,hcell,hc⟩ := hm.some cell
    cases hc with
    | thunk hr => exact ⟨_,Or.inl (.E_Force (app _ _ hv) sig kind hcell),.run hr (.cons (.update _) hk) hm⟩
  | E_Update hv =>
    have ht := (hv ▸ hq.view).ret_inv
    cases hk with
    | cons hf hk => cases hf with
      | update l => exact ⟨_,Or.inl (.E_Update ht),.run (.refl _) hk (hm.set (.done _))⟩
  | E_Mark hv =>
    have ht := (hv ▸ hq.view).ret_inv
    cases hk with
    | cons hf hk => cases hf with
      | mark => exact ⟨_,Or.inl (.E_Mark ht),.run (.refl _) hk hm⟩
  | E_EscLet hv =>
    have ht := (hv ▸ hq.view).escape_inv
    cases hk with
    | cons hf hk => cases hf with
      | letF _ => exact ⟨_,Or.inl (.E_EscLet ht),.run (.refl _) hk hm⟩
  | E_EscHandle hv =>
    have ht := (hv ▸ hq.view).escape_inv
    cases hk with
    | cons hf hk => cases hf with
      | handleF _ => exact ⟨_,Or.inl (.E_EscHandle ht),.run (.refl _) hk hm⟩
  | E_EscMark hv =>
    have ht := (hv ▸ hq.view).escape_inv
    cases hk with
    | cons hf hk => cases hf with
      | mark => exact ⟨_,Or.inl (.E_EscMark ht),.run (.refl _) hk hm⟩
  | E_Release hv response =>
    have ht := (hv ▸ hq.view).ret_inv
    cases hk with
    | cons hf hk => cases hf with
      | release v => exact ⟨_,Or.inl (.E_Release ht response),.run (.refl _) hk hm⟩
  | E_RelErr hv response =>
    have ht := (hv ▸ hq.view).ret_inv
    cases hk with
    | cons hf hk => cases hf with
      | release v => exact ⟨_,Or.inl (.E_RelErr ht response),.error hk hm⟩
  | E_EscRel hv response =>
    have ht := (hv ▸ hq.view).escape_inv
    cases hk with
    | cons hf hk => cases hf with
      | release v => exact ⟨_,Or.inl (.E_EscRel ht response),.run (.refl _) hk hm⟩
  | E_EscRelErr hv response =>
    have ht := (hv ▸ hq.view).escape_inv
    cases hk with
    | cons hf hk => cases hf with
      | release v => exact ⟨_,Or.inl (.E_EscRelErr ht response),.error hk hm⟩
  | E_HRet hv =>
    have ht := (hv ▸ hq.view).ret_inv
    cases hk with
    | cons hf hk => cases hf with
      | handleF _ => exact ⟨_,Or.inl (.E_HRet ht),.run (.refl _) hk hm⟩
  | E_Op hv split find fresh =>
    obtain ⟨l1,ds,l2,hs,h1,hcs,h2⟩ := hk.splitAt split
    obtain ⟨d,hfind,hcd⟩ := hcs.find _ find
    have hb := hcd.single_body
    exact ⟨_,Or.inl (.E_Op (app _ _ hv) hs hfind (hm.none fresh)),
      .run (.code (hb.substTy 0 _ _)) (.cons (.drop _) h2)
        (hm.set (.cont (h1.append (.cons (.handleF hcs) .nil))))⟩
  | E_OpFail hv split fresh =>
    obtain ⟨l1,ds,l2,hs,h1,hcs,h2⟩ := hk.splitAt split
    cases hcs with
    | fail hb hn =>
      cases hn
      exact ⟨_,Or.inl (.E_OpFail (app _ _ hv) hs (hm.none fresh)),
        .run (.code (hb.substTy 0 _ _)) (.cons (.drop _) h2)
          (hm.set (.cont (h1.append (.cons (.handleF (.fail hb .nil)) .nil))))⟩
  | E_OpPrim hv sig kind split find fresh =>
    obtain ⟨l1,ds,l2,hs,h1,hcs,h2⟩ := hk.splitAt split
    obtain ⟨d,hfind,hcd⟩ := hcs.find _ find
    have hb := hcd.single_body
    exact ⟨_,Or.inl (.E_OpPrim (app _ _ hv) sig kind hs hfind (hm.none fresh)),
      .run (.code (hb.substTy 0 _ _)) (.cons (.drop _) h2)
        (hm.set (.cont (h1.append (.cons (.handleF hcs) .nil))))⟩
  | E_Resume hv cell =>
    have ht := (hv ▸ hq.view).atomic_inv (by simp)
    obtain ⟨c,hcell,hc⟩ := hm.some cell
    cases hc with
    | cont hr => exact ⟨_,Or.inl (.E_Resume ht hcell),.run (.refl _) (hr.append hk) (hm.set .used)⟩
  | E_ResumeErr hv cell =>
    have ht := (hv ▸ hq.view).atomic_inv (by simp)
    obtain ⟨c,hcell,hc⟩ := hm.some cell
    cases hc
    exact ⟨_,Or.inl (.E_ResumeErr ht hcell),.error hk hm⟩
  | E_Drop hv cell =>
    have ht := (hv ▸ hq.view).ret_inv
    obtain ⟨c,hcell,hc⟩ := hm.some cell
    cases hc
    cases hk with
    | cons hf hk => cases hf with
      | drop l => exact ⟨_,Or.inl (.E_Drop ht hcell),.run (.refl _) hk hm⟩
  | E_DropRel hv cell =>
    have ht := (hv ▸ hq.view).ret_inv
    obtain ⟨c,hcell,hc⟩ := hm.some cell
    cases hc with
    | cont hr =>
      cases hk with
      | cons hf hk => cases hf with
        | drop l => exact ⟨_,Or.inl (.E_DropRel ht hcell),.run (.refl _) (hr.releases.append hk) (hm.set .used)⟩
  | E_EscDrop hv cell =>
    have ht := (hv ▸ hq.view).escape_inv
    obtain ⟨c,hcell,hc⟩ := hm.some cell
    cases hc
    cases hk with
    | cons hf hk => cases hf with
      | drop l => exact ⟨_,Or.inl (.E_EscDrop ht hcell),.run (.refl _) hk hm⟩
  | E_EscDropRel hv cell =>
    have ht := (hv ▸ hq.view).escape_inv
    obtain ⟨c,hcell,hc⟩ := hm.some cell
    cases hc with
    | cont hr =>
      cases hk with
      | cons hf hk => cases hf with
        | drop l => exact ⟨_,Or.inl (.E_EscDropRel ht hcell),.run (.refl _) (hr.releases.append hk) (hm.set .used)⟩
/-- 照合・失敗・終了を含む全状態の一段の模倣。 -/
theorem state_step {P B σ s t label s'} (ha : Agreement B)
    (hr : StateRel s t) (hs : Step P B σ s label s') : Matches P B σ s t label s' := by
  cases hr with
  | run hq hk hm => exact run_step ha hq hk hm hs
  | matchRun harms hk hm =>
    cases hs with
    | E_MatchSkip hg halt =>
      obtain ⟨guard,body,hg',_,_⟩ := harms.get hg
      exact ⟨_,Or.inl (.E_MatchSkip hg' halt),.matchRun harms hk hm⟩
    | E_MatchBody hg halt =>
      obtain ⟨guard,body,hg',hb,hguard⟩ := harms.get hg
      cases hguard
      exact ⟨_,Or.inl (.E_MatchBody hg' halt),.run (.code hb) hk hm⟩
    | E_MatchGuard hg halt =>
      obtain ⟨guard,body,hg',hb,hguard⟩ := harms.get hg
      cases hguard with
      | some hc => exact ⟨_,Or.inl (.E_MatchGuard hg' halt),
          .run (.code hc) (.cons (.guardF harms (.code hb)) hk) hm⟩
  | error hk hm =>
    cases hs with
    | E_ErrPopGuard => cases hk with
      | cons hf hk => cases hf; exact ⟨_,Or.inl .E_ErrPopGuard,.error hk hm⟩
    | E_ErrPopLet => cases hk with
      | cons hf hk => cases hf; exact ⟨_,Or.inl .E_ErrPopLet,.error hk hm⟩
    | E_ErrPopMark => cases hk with
      | cons hf hk => cases hf; exact ⟨_,Or.inl .E_ErrPopMark,.error hk hm⟩
    | E_ErrPopUpdate => cases hk with
      | cons hf hk => cases hf; exact ⟨_,Or.inl .E_ErrPopUpdate,.error hk hm⟩
    | E_ErrPopHandle => cases hk with
      | cons hf hk => cases hf; exact ⟨_,Or.inl .E_ErrPopHandle,.error hk hm⟩
    | E_ErrRel h => cases hk with
      | cons hf hk => cases hf; exact ⟨_,Or.inl (.E_ErrRel h),.error hk hm⟩
    | E_ErrRelErr h => cases hk with
      | cons hf hk => cases hf; exact ⟨_,Or.inl (.E_ErrRelErr h),.error hk hm⟩
    | E_ErrDrop cell =>
      obtain ⟨c,hcell,hc⟩ := hm.some cell
      cases hc
      cases hk with
      | cons hf hk => cases hf; exact ⟨_,Or.inl (.E_ErrDrop hcell),.error hk hm⟩
    | E_ErrDropRel cell =>
      obtain ⟨c,hcell,hc⟩ := hm.some cell
      cases hc with
      | cont hc => cases hk with
        | cons hf hk => cases hf; exact ⟨_,Or.inl (.E_ErrDropRel hcell),.error (hc.releases.append hk) (hm.set .used)⟩
  | exit hk hm =>
    cases hs with
    | E_ExitPopGuard => cases hk with
      | cons hf hk => cases hf; exact ⟨_,Or.inl .E_ExitPopGuard,.exit hk hm⟩
    | E_ExitPopLet => cases hk with
      | cons hf hk => cases hf; exact ⟨_,Or.inl .E_ExitPopLet,.exit hk hm⟩
    | E_ExitPopMark => cases hk with
      | cons hf hk => cases hf; exact ⟨_,Or.inl .E_ExitPopMark,.exit hk hm⟩
    | E_ExitPopUpdate => cases hk with
      | cons hf hk => cases hf; exact ⟨_,Or.inl .E_ExitPopUpdate,.exit hk hm⟩
    | E_ExitPopHandle => cases hk with
      | cons hf hk => cases hf; exact ⟨_,Or.inl .E_ExitPopHandle,.exit hk hm⟩
    | E_ExitRel h => cases hk with
      | cons hf hk => cases hf; exact ⟨_,Or.inl (.E_ExitRel h),.exit hk hm⟩
    | E_ExitRelErr h => cases hk with
      | cons hf hk => cases hf; exact ⟨_,Or.inl (.E_ExitRelErr h),.exit hk hm⟩
    | E_ExitDrop cell =>
      obtain ⟨c,hcell,hc⟩ := hm.some cell
      cases hc
      cases hk with
      | cons hf hk => cases hf; exact ⟨_,Or.inl (.E_ExitDrop hcell),.exit hk hm⟩
    | E_ExitDropRel cell =>
      obtain ⟨c,hcell,hc⟩ := hm.some cell
      cases hc with
      | cont hc => cases hk with
        | cons hf hk => cases hf; exact ⟨_,Or.inl (.E_ExitDropRel hcell),.exit (hc.releases.append hk) (hm.set .used)⟩

/-- 模倣を有限の事象列へ持ち上げる。 -/
theorem finite_forward {P B σ s t evs z} (ha : Agreement B) (hr : StateRel s t)
    (hs : Steps P B σ s evs z) :
    ∃ z', Steps (eraseProgram P) B σ t evs z' ∧ StateRel z z' := by
  induction hs generalizing t with
  | nil => exact ⟨_,.nil,hr⟩
  | cons step rest ih =>
    obtain ⟨dest,hm,hr'⟩ := state_step ha hr step
    obtain ⟨z',hrest,hz⟩ := ih hr'
    rcases hm with hstep | ⟨rfl,rfl,_⟩
    · exact ⟨_,.cons hstep hrest,hz⟩
    · exact ⟨_,hrest,hz⟩

end
end Benitoite.Release.Refinement.SafeCheckErasure
