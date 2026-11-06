import Benitoite.Release.Refinement.SafeCheckSimulation

/-! # 消去後の遷移から元の実行への対応 -/
namespace Benitoite.Release.Refinement.SafeCheckErasure
noncomputable section
open CheckErasure RefinementCheck

theorem Code.app_right {m f vs} (h : Code m (.app f vs)) : m = .app f vs := by cases h; rfl

theorem Code.escape_right {m v} (h : Code m (.escape v)) : m = .escape v := by cases h; rfl

theorem Code.builder_right {z k m} (h : Code z (.builderLet k m)) :
    ∃ n, z = .builderLet k n ∧ Code n m := by
  cases h with
  | same _ => exact ⟨_,rfl,.same _⟩
  | builder h => exact ⟨_,rfl,h⟩

theorem Code.let_right {z m n} (h : Code z (.letIn m n)) :
    ∃ m' n', z = .letIn m' n' ∧ Code m' m ∧ Code n' n := by
  cases h with
  | same _ => exact ⟨_,_,rfl,.same _,.same _⟩
  | letIn h g => exact ⟨_,_,rfl,h,g⟩

theorem Code.ite_right {z v m n} (h : Code z (.ite v m n)) :
    ∃ m' n', z = .ite v m' n' ∧ Code m' m ∧ Code n' n := by
  cases h with
  | same _ => exact ⟨_,_,rfl,.same _,.same _⟩
  | ite h g => exact ⟨_,_,rfl,h,g⟩

theorem Code.match_right {z v bs} (h : Code z (.match v bs)) :
    ∃ as, z = .match v as ∧ Arms as bs := by
  cases h with
  | same _ => exact ⟨_,rfl,.refl _⟩
  | matchC h => exact ⟨_,rfl,h⟩

theorem Code.lazy_right {z n} (h : Code z (.lazyC n)) :
    ∃ m, z = .lazyC m ∧ Code m n := by
  cases h with
  | same _ => exact ⟨_,rfl,.same _⟩
  | lazyC h => exact ⟨_,rfl,h⟩

theorem Code.use_right {z v n} (h : Code z (.use v n)) :
    ∃ m, z = .use v m ∧ Code m n := by
  cases h with
  | same _ => exact ⟨_,rfl,.same _⟩
  | use h => exact ⟨_,rfl,h⟩

theorem Code.handle_right {z n ds} (h : Code z (.handle n ds)) :
    ∃ m cs, z = .handle m cs ∧ Code m n ∧ Clauses cs ds := by
  cases h with
  | same _ => exact ⟨_,_,rfl,.same _,.refl _⟩
  | handle h g => exact ⟨_,_,rfl,h,g⟩

theorem Code.atomic_right {m n} (h : Code m n)
    (ha : (∀ k x, n ≠ .builderLet k x) ∧ (∀ x y, n ≠ .letIn x y) ∧
      (∀ v, n ≠ .ret v) ∧ (∀ v x y, n ≠ .ite v x y) ∧
      (∀ v as, n ≠ .match v as) ∧ (∀ x, n ≠ .lazyC x) ∧
      (∀ v x, n ≠ .use v x) ∧ (∀ x cs, n ≠ .handle x cs)) : m = n := by
  cases h with
  | same _ => rfl
  | check _ => exact (ha.2.2.1 _ rfl).elim
  | builder _ => exact (ha.1 _ _ rfl).elim
  | letIn _ _ => exact (ha.2.1 _ _ rfl).elim
  | ite _ _ => exact (ha.2.2.2.1 _ _ _ rfl).elim
  | matchC _ => exact (ha.2.2.2.2.1 _ _ rfl).elim
  | lazyC _ => exact (ha.2.2.2.2.2.1 _ rfl).elim
  | use _ => exact (ha.2.2.2.2.2.2.1 _ _ rfl).elim
  | handle _ _ => exact (ha.2.2.2.2.2.2.2 _ _ rfl).elim

/-- 元の実行で、今消す根の検査がない状態。 -/
def RootReady (q q' : Closure) : Prop :=
  ¬∃ t u v cap, Site t u v ∧ q.view = call t u v ∧ q' = .mk cap (.ret (ok u v))

theorem ClosureRel.ret_right {q q' v} (h : ClosureRel q q') (hr : RootReady q q') (hv : q'.view = .ret v) :
    q.view = .ret v := by
  cases h with
  | @returned cap cap' value h => simpa only [Closure.view,Closure.code,Closure.capture,h] using hv
  | code h => cases h with
    | same _ => exact hv
    | check h => exact (hr ⟨_,_,_,_,h,(h.stable.view _).1,rfl⟩).elim
    | _ => simp [Closure.view,Closure.code,Closure.capture] at hv

theorem ClosureRel.capture_eq_right {q q'} (h : ClosureRel q q') (hn : ∀ v, q'.view ≠ .ret v) :
    q.capture = q'.capture := by
  rcases h.capture with he | ⟨v,_,hv⟩
  · exact he
  · exact (hn v hv).elim

theorem ClosureRel.checkAt_right {q q' k o sh bs p v ix} (h : ClosureRel q q')
    (hv : q'.code = .checkAt k o sh bs p v ix) :
    q.code = .checkAt k o sh bs p v ix ∧ q.capture = q'.capture := by
  cases h with
  | code h =>
    simp only [Closure.code] at hv
    exact ⟨(hv ▸ h).atomic_right (by simp),rfl⟩
  | returned _ => cases hv

theorem StoreRel.none_right {μ ν l} (h : StoreRel μ ν) (e : ν l = Option.none) : μ l = Option.none := by
  have hr := h l
  rw [e] at hr
  cases ho : μ l with
  | none => rfl
  | some c => rw [ho] at hr; cases hr

theorem StoreRel.some_right {μ ν l d} (h : StoreRel μ ν) (e : ν l = Option.some d) :
    ∃ c, μ l = Option.some c ∧ CellRel c d := by
  have hr := h l
  rw [e] at hr
  cases ho : μ l with
  | none => rw [ho] at hr; cases hr
  | some c => rw [ho] at hr; cases hr with
    | some hc => exact ⟨c,rfl,hc⟩

theorem Arms.get_right {as bs : List Arm} (h : Arms as bs) {i : Nat} {alts : List Alt} {guard : Option Comp} {body : Comp}
    (hg : bs[i]? = some (.mk alts guard body)) :
    ∃ guard' body', as[i]? = some (.mk alts guard' body') ∧ Code body' body ∧ Option.Rel Code guard' guard := by
  cases h with
  | nil => simp at hg
  | plain h g => cases i with
    | zero => cases hg; exact ⟨_,_,rfl,h,.none⟩
    | succ i => exact g.get_right hg
  | guard h g k => cases i with
    | zero => cases hg; exact ⟨_,_,rfl,g,.some h⟩
    | succ i => exact k.get_right hg

theorem Clauses.find_right {cs ds} (h : Clauses cs ds) (o : OpRef) {d}
    (hd : findClause ds o = some d) : ∃ c, findClause cs o = some c ∧ Clauses [c] [d] := by
  cases h with
  | nil => simp [findClause] at hd
  | op h g =>
    simp only [findClause,List.find?_cons,Clause.op] at hd ⊢
    split at hd
    · cases hd; exact ⟨_,rfl,.op h .nil⟩
    · exact g.find_right o hd
  | fail h g =>
    simp only [findClause,List.find?_cons,Clause.op] at hd ⊢
    split at hd
    · cases hd; exact ⟨_,rfl,.fail h .nil⟩
    · exact g.find_right o hd

theorem ContRel.mem_left {k l} (h : ContRel k l) {f} (hf : f ∈ k) : ∃ g ∈ l, FrameRel f g := by
  induction h with
  | nil => cases hf
  | cons hr _ ih =>
    rcases List.mem_cons.mp hf with rfl | hf
    · exact ⟨_,List.mem_cons_self,hr⟩
    · obtain ⟨g,hg,hrel⟩ := ih hf; exact ⟨g,List.mem_cons_of_mem _ hg,hrel⟩

theorem ContRel.noHandler_right {k l} (h : ContRel k l) {o} (hn : NoHandler l o) : NoHandler k o := by
  intro cap cs hm
  obtain ⟨f,hf,hr⟩ := h.mem_left hm
  cases hr with
  | handleF hc => rw [hc.handles o]; exact hn _ _ hf

theorem ContRel.split_right {k l} (h : ContRel k l) {l1 cap ds l2}
    (he : l = l1 ++ .handleF cap ds :: l2) :
    ∃ k1 cs k2, k = k1 ++ .handleF cap cs :: k2 ∧ ContRel k1 l1 ∧ Clauses cs ds ∧ ContRel k2 l2 := by
  subst l
  induction l1 generalizing k with
  | nil => cases h with
    | cons hf hk => cases hf with
      | handleF hc => exact ⟨[],_,_,rfl,.nil,hc,hk⟩
  | cons f l1 ih => cases h with
    | cons hf hk =>
      obtain ⟨k1,cs,k2,he,h1,hc,h2⟩ := ih hk
      subst he
      exact ⟨_ :: k1,cs,k2,rfl,.cons hf h1,hc,h2⟩

theorem ContRel.splitAt_right {k l l1 cap ds l2 o} (h : ContRel k l) (hs : SplitAt o l l1 cap ds l2) :
    ∃ k1 cs k2, SplitAt o k k1 cap cs k2 ∧ ContRel k1 l1 ∧ Clauses cs ds ∧ ContRel k2 l2 := by
  obtain ⟨k1,cs,k2,he,h1,hc,h2⟩ := h.split_right hs.1
  exact ⟨k1,cs,k2,⟨he,(hc.handles o).symm ▸ hs.2.1,h1.noHandler_right hs.2.2⟩,h1,hc,h2⟩

/-- 根の検査を既に処理した対応では、消去後の一段に元の一段がある。 -/
theorem run_reflect_core {P B σ q q' k k' μ μ' label dest}
    (hq : ClosureRel q q') (hk : ContRel k k') (hm : StoreRel μ μ') (root : RootReady q q')
    (hs : Step (eraseProgram P) B σ (.run q' k' μ') label dest) :
    ∃ source, Step P B σ (.run q k μ) label source ∧ StateRel source dest := by
  have app : ∀ f vs, q'.view = .app f vs → q.view = .app f vs := by
    intro f vs hv
    exact (hv ▸ hq.view).app_right
  have cap : (∀ v, q'.view ≠ .ret v) → q.capture = q'.capture := hq.capture_eq_right
  cases hs with
  | E_Let hv =>
    obtain ⟨m,n,ht,h1,h2⟩ := (hv ▸ hq.view).let_right
    have hc := cap (by intro v h; rw [hv] at h; cases h)
    refine ⟨_,(.E_Let ht),.run ?_ (.cons (.letF ?_) hk) hm⟩
    · simpa only [hc] using (ClosureRel.code h1)
    · simpa only [hc] using (ClosureRel.code h2)
  | E_IfT hv =>
    obtain ⟨m,n,ht,h1,_⟩ := (hv ▸ hq.view).ite_right
    have hc := cap (by intro v h; rw [hv] at h; cases h)
    exact ⟨_,(.E_IfT ht),.run (by simpa only [hc] using ClosureRel.code h1) hk hm⟩
  | E_IfF hv =>
    obtain ⟨m,n,ht,_,h2⟩ := (hv ▸ hq.view).ite_right
    have hc := cap (by intro v h; rw [hv] at h; cases h)
    exact ⟨_,(.E_IfF ht),.run (by simpa only [hc] using ClosureRel.code h2) hk hm⟩
  | E_Match hv =>
    obtain ⟨as,ht,harms⟩ := (hv ▸ hq.view).match_right
    have hc := cap (by intro v h; rw [hv] at h; cases h)
    exact ⟨_,(.E_Match ht),by simpa only [hc] using StateRel.matchRun harms hk hm⟩
  | E_Handle hv =>
    obtain ⟨m,cs,ht,hbody,hcs⟩ := (hv ▸ hq.view).handle_right
    have hc := cap (by intro v h; rw [hv] at h; cases h)
    refine ⟨_,(.E_Handle ht),?_⟩
    simpa only [hc] using StateRel.run (.code hbody) (.cons (.handleF hcs) hk) hm
  | E_Use hv =>
    obtain ⟨m,ht,hbody⟩ := (hv ▸ hq.view).use_right
    have hc := cap (by intro v h; rw [hv] at h; cases h)
    exact ⟨_,(.E_Use ht),.run (by simpa only [hc] using ClosureRel.code hbody) (.cons (.release _) hk) hm⟩
  | E_Prim hv sig kind delta =>
    exact ⟨_,(.E_Prim (app _ _ hv) sig kind delta),.run (.refl _) hk hm⟩
  | E_Err hv sig kind delta =>
    exact ⟨_,(.E_Err (app _ _ hv) sig kind delta),.error hk hm⟩
  | E_Lam hv closed arity =>
    exact ⟨_,(.E_Lam (app _ _ hv) closed arity),.run (.refl _) hk.markPush hm⟩
  | E_ExternalApply hv =>
    exact ⟨_,(.E_ExternalApply (app _ _ hv)),.run (.refl _) hk hm⟩
  | E_PathBasesApply hv sig kind =>
    have hc := cap (by intro v h; rw [hv] at h; cases h)
    exact ⟨_,(.E_PathBasesApply (app _ _ hv) sig kind),.run (by simpa only [hc] using ClosureRel.code (.same _)) hk hm⟩
  | E_RefNew hv sig kind fresh =>
    exact ⟨_,(.E_RefNew (app _ _ hv) sig kind (hm.none_right fresh)),.run (.refl _) hk (hm.set (.value _))⟩
  | E_RefSet hv sig kind =>
    exact ⟨_,(.E_RefSet (app _ _ hv) sig kind),.run (.refl _) hk (hm.set (.value _))⟩
  | E_RefUpdate hv sig kind =>
    exact ⟨_,(.E_RefUpdate (app _ _ hv) sig kind),.run (.refl _) hk hm⟩
  | @E_Fun f ts es rs ws _ _ d _ hv hd hws hts hes =>
    obtain ⟨original,ho,he⟩ := Option.map_eq_some_iff.mp hd
    subst d
    refine ⟨_,(.E_Fun (app _ _ hv) ho hws hts hes),.run (.code ?_) hk.markPush hm⟩
    exact (erase_code _).instR _ |>.substTy 0 _ _
  | E_BuilderNew hv fresh =>
    obtain ⟨m,ht,hbody⟩ := (hv ▸ hq.view).builder_right
    have hc := cap (by intro v h; rw [hv] at h; cases h)
    refine ⟨_,(.E_BuilderNew ht (hm.none_right fresh)),.run ?_ hk (hm.set (.builder _))⟩
    simpa only [hc] using ClosureRel.code (hbody.subst builderValueSubst _)
  | E_BuilderOp hv cell result =>
    have ht := (hv ▸ hq.view).atomic_right (by simp)
    obtain ⟨c,hcell,hc⟩ := hm.some_right cell
    cases hc
    exact ⟨_,(.E_BuilderOp ht hcell result),.run (.refl _) hk (hm.set (.builder _))⟩
  | E_BuilderErr hv cell result =>
    have ht := (hv ▸ hq.view).atomic_right (by simp)
    obtain ⟨c,hcell,hc⟩ := hm.some_right cell
    cases hc
    exact ⟨_,(.E_BuilderErr ht hcell result),.error hk hm⟩
  | E_Return hv =>
    have ht := hq.ret_right root hv
    cases hk with
    | cons hf hk => cases hf with
      | letF hr => exact ⟨_,(.E_Return ht),.run (hr.apply _) hk hm⟩
  | E_External hv decl response receive =>
    have ht := (hv ▸ hq.view).atomic_right (by simp)
    exact ⟨_,(.E_External ht decl response (by simpa only [externalReceive_program] using receive)),.run (.refl _) hk hm⟩
  | E_ExternalErr hv decl response receive =>
    have ht := (hv ▸ hq.view).atomic_right (by simp)
    exact ⟨_,(.E_ExternalErr ht decl response (by simpa only [externalReceive_program] using receive)),.error hk hm⟩
  | E_IssuePathBases hv sig kind hop valid =>
    have ht := (hv ▸ hq.view).atomic_right (by simp)
    exact ⟨_,(.E_IssuePathBases ht sig kind hop valid),.run (.refl _) hk hm⟩
  | E_AtOk hv prepare shape check =>
    obtain ⟨ht,hc⟩ := hq.checkAt_right hv
    refine ⟨_,(.E_AtOk ht (hc.symm ▸ prepare) shape check),.run ?_ hk hm⟩
    simpa only [hc] using ClosureRel.refl _
  | E_AtError hv prepare shape check =>
    obtain ⟨ht,hc⟩ := hq.checkAt_right hv
    refine ⟨_,(.E_AtError ht (hc.symm ▸ prepare) shape check),.run ?_ hk hm⟩
    simpa only [hc] using ClosureRel.refl _
  | E_AtPrepareError hv prepare =>
    obtain ⟨ht,hc⟩ := hq.checkAt_right hv
    refine ⟨_,(.E_AtPrepareError ht (hc.symm ▸ prepare)),.run ?_ hk hm⟩
    simpa only [hc] using ClosureRel.refl _
  | E_Meth hv id body cd ms hw hvlen ht hs he =>
    have hview := (hv ▸ hq.view).atomic_right (by simp)
    exact ⟨_,(.E_Meth hview id body cd ms hw hvlen ht hs he),.run (.refl _) hk.markPush hm⟩
  | E_Super hv step =>
    have ht := (hv ▸ hq.view).atomic_right (by simp)
    exact ⟨_,(.E_Super ht (by simpa only [superStep_program] using step)),.run (.refl _) hk hm⟩
  | E_GuardT hv =>
    have ht := hq.ret_right root hv
    cases hk with
    | cons hf hk => cases hf with
      | guardF ha hb => exact ⟨_,(.E_GuardT ht),.run hb hk hm⟩
  | E_GuardF hv =>
    have ht := hq.ret_right root hv
    cases hk with
    | cons hf hk => cases hf with
      | guardF ha hb => exact ⟨_,(.E_GuardF ht),.matchRun ha hk hm⟩
  | E_IO hv sig kind handler response =>
    exact ⟨_,(.E_IO (app _ _ hv) sig kind (hk.noHandler_right handler) response),.run (.refl _) hk hm⟩
  | E_IOErr hv sig kind handler response =>
    exact ⟨_,(.E_IOErr (app _ _ hv) sig kind (hk.noHandler_right handler) response),.error hk hm⟩
  | E_Exit hv sig kind handler response =>
    exact ⟨_,(.E_Exit (app _ _ hv) sig kind (hk.noHandler_right handler) response),.exit hk hm⟩
  | E_RefGet hv sig kind cell =>
    obtain ⟨c,hcell,hc⟩ := hm.some_right cell
    cases hc
    exact ⟨_,(.E_RefGet (app _ _ hv) sig kind hcell),.run (.refl _) hk hm⟩
  | E_Lazy hv fresh =>
    obtain ⟨m,ht,hbody⟩ := (hv ▸ hq.view).lazy_right
    have hc := cap (by intro v h; rw [hv] at h; cases h)
    refine ⟨_,(.E_Lazy ht (hm.none_right fresh)),.run (.refl _) hk (hm.set (.thunk ?_))⟩
    simpa only [hc] using ClosureRel.code hbody
  | E_ForceDone hv sig kind cell =>
    obtain ⟨c,hcell,hc⟩ := hm.some_right cell
    cases hc
    exact ⟨_,(.E_ForceDone (app _ _ hv) sig kind hcell),.run (.refl _) hk hm⟩
  | E_Force hv sig kind cell =>
    obtain ⟨c,hcell,hc⟩ := hm.some_right cell
    cases hc with
    | thunk hr => exact ⟨_,(.E_Force (app _ _ hv) sig kind hcell),.run hr (.cons (.update _) hk) hm⟩
  | E_Update hv =>
    have ht := hq.ret_right root hv
    cases hk with
    | cons hf hk => cases hf with
      | update l => exact ⟨_,(.E_Update ht),.run (.refl _) hk (hm.set (.done _))⟩
  | E_Mark hv =>
    have ht := hq.ret_right root hv
    cases hk with
    | cons hf hk => cases hf with
      | mark => exact ⟨_,(.E_Mark ht),.run (.refl _) hk hm⟩
  | E_EscLet hv =>
    have ht := (hv ▸ hq.view).escape_right
    cases hk with
    | cons hf hk => cases hf with
      | letF _ => exact ⟨_,(.E_EscLet ht),.run (.refl _) hk hm⟩
  | E_EscHandle hv =>
    have ht := (hv ▸ hq.view).escape_right
    cases hk with
    | cons hf hk => cases hf with
      | handleF _ => exact ⟨_,(.E_EscHandle ht),.run (.refl _) hk hm⟩
  | E_EscMark hv =>
    have ht := (hv ▸ hq.view).escape_right
    cases hk with
    | cons hf hk => cases hf with
      | mark => exact ⟨_,(.E_EscMark ht),.run (.refl _) hk hm⟩
  | E_Release hv response =>
    have ht := hq.ret_right root hv
    cases hk with
    | cons hf hk => cases hf with
      | release v => exact ⟨_,(.E_Release ht response),.run (.refl _) hk hm⟩
  | E_RelErr hv response =>
    have ht := hq.ret_right root hv
    cases hk with
    | cons hf hk => cases hf with
      | release v => exact ⟨_,(.E_RelErr ht response),.error hk hm⟩
  | E_EscRel hv response =>
    have ht := (hv ▸ hq.view).escape_right
    cases hk with
    | cons hf hk => cases hf with
      | release v => exact ⟨_,(.E_EscRel ht response),.run (.refl _) hk hm⟩
  | E_EscRelErr hv response =>
    have ht := (hv ▸ hq.view).escape_right
    cases hk with
    | cons hf hk => cases hf with
      | release v => exact ⟨_,(.E_EscRelErr ht response),.error hk hm⟩
  | E_HRet hv =>
    have ht := hq.ret_right root hv
    cases hk with
    | cons hf hk => cases hf with
      | handleF _ => exact ⟨_,(.E_HRet ht),.run (.refl _) hk hm⟩
  | E_Op hv split find fresh =>
    obtain ⟨l1,ds,l2,hs,h1,hcs,h2⟩ := hk.splitAt_right split
    obtain ⟨d,hfind,hcd⟩ := hcs.find_right _ find
    have hb := hcd.single_body
    exact ⟨_,(.E_Op (app _ _ hv) hs hfind (hm.none_right fresh)),
      .run (.code (hb.substTy 0 _ _)) (.cons (.drop _) h2)
        (hm.set (.cont (h1.append (.cons (.handleF hcs) .nil))))⟩
  | E_OpFail hv split fresh =>
    obtain ⟨l1,ds,l2,hs,h1,hcs,h2⟩ := hk.splitAt_right split
    cases hcs with
    | fail hb hn =>
      cases hn
      exact ⟨_,(.E_OpFail (app _ _ hv) hs (hm.none_right fresh)),
        .run (.code (hb.substTy 0 _ _)) (.cons (.drop _) h2)
          (hm.set (.cont (h1.append (.cons (.handleF (.fail hb .nil)) .nil))))⟩
  | E_OpPrim hv sig kind split find fresh =>
    obtain ⟨l1,ds,l2,hs,h1,hcs,h2⟩ := hk.splitAt_right split
    obtain ⟨d,hfind,hcd⟩ := hcs.find_right _ find
    have hb := hcd.single_body
    exact ⟨_,(.E_OpPrim (app _ _ hv) sig kind hs hfind (hm.none_right fresh)),
      .run (.code (hb.substTy 0 _ _)) (.cons (.drop _) h2)
        (hm.set (.cont (h1.append (.cons (.handleF hcs) .nil))))⟩
  | E_Resume hv cell =>
    have ht := (hv ▸ hq.view).atomic_right (by simp)
    obtain ⟨c,hcell,hc⟩ := hm.some_right cell
    cases hc with
    | cont hr => exact ⟨_,(.E_Resume ht hcell),.run (.refl _) (hr.append hk) (hm.set .used)⟩
  | E_ResumeErr hv cell =>
    have ht := (hv ▸ hq.view).atomic_right (by simp)
    obtain ⟨c,hcell,hc⟩ := hm.some_right cell
    cases hc
    exact ⟨_,(.E_ResumeErr ht hcell),.error hk hm⟩
  | E_Drop hv cell =>
    have ht := hq.ret_right root hv
    obtain ⟨c,hcell,hc⟩ := hm.some_right cell
    cases hc
    cases hk with
    | cons hf hk => cases hf with
      | drop l => exact ⟨_,(.E_Drop ht hcell),.run (.refl _) hk hm⟩
  | E_DropRel hv cell =>
    have ht := hq.ret_right root hv
    obtain ⟨c,hcell,hc⟩ := hm.some_right cell
    cases hc with
    | cont hr =>
      cases hk with
      | cons hf hk => cases hf with
        | drop l => exact ⟨_,(.E_DropRel ht hcell),.run (.refl _) (hr.releases.append hk) (hm.set .used)⟩
  | E_EscDrop hv cell =>
    have ht := (hv ▸ hq.view).escape_right
    obtain ⟨c,hcell,hc⟩ := hm.some_right cell
    cases hc
    cases hk with
    | cons hf hk => cases hf with
      | drop l => exact ⟨_,(.E_EscDrop ht hcell),.run (.refl _) hk hm⟩
  | E_EscDropRel hv cell =>
    have ht := (hv ▸ hq.view).escape_right
    obtain ⟨c,hcell,hc⟩ := hm.some_right cell
    cases hc with
    | cont hr =>
      cases hk with
      | cons hf hk => cases hf with
        | drop l => exact ⟨_,(.E_EscDropRel ht hcell),.run (.refl _) (hr.releases.append hk) (hm.set .used)⟩
/-- 少なくとも一段を持つ、元の実行の到達。 -/
inductive Descends (P : Program) (B : Builtins) (σ : PathEnv) : State → State → Prop
  | one {s t label} : Step P B σ s label t → Descends P B σ t s
  | more {s t z label} : Step P B σ s label t → Descends P B σ z t → Descends P B σ z s

/-- 一段のラベルから事象だけを残す。 -/
theorem step_steps {P B σ s label t} (h : Step P B σ s label t) : Steps P B σ s label.toList t := by
  cases label <;> exact .cons h .nil

/-- 根の検査を事象なしで処理してから、消去後の一段と対応する元の一段を実行する。 -/
theorem run_reflect {P B σ q q' k k' μ μ' label dest}
    (ha : Agreement B) (hq : ClosureRel q q') (hk : ContRel k k') (hm : StoreRel μ μ')
    (hs : Step (eraseProgram P) B σ (.run q' k' μ') label dest) :
    ∃ source, Steps P B σ (.run q k μ) label.toList source ∧ Descends P B σ source (.run q k μ) ∧ StateRel source dest := by
  classical
  by_cases root : ∃ t u v cap, Site t u v ∧ q.view = call t u v ∧ q' = .mk cap (.ret (ok u v))
  · obtain ⟨t,u,v,cap,site,hview,rfl⟩ := root
    have first := CheckErasure.erased_step (P := P) (σ := σ) (k := k) (μ := μ)
      hview ha.signature (ha.delta t u v) (site.stable.view Capture.empty).1
      site.normalSource site.normalExpected site.core site.accepts
    rw [CheckErasure.erase_check (site.stable.view Capture.empty).1 site.normalSource site.normalExpected site.core site.accepts] at first
    have hr : ClosureRel (Closure.pure (.ret (ok u v))) (.mk cap (.ret (ok u v))) := .returned site.result_static
    have hready : RootReady (Closure.pure (.ret (ok u v))) (.mk cap (.ret (ok u v))) := by
      rintro ⟨t',u',v',cap',_,hv,_⟩
      simp [Closure.pure,Closure.view,Closure.code,Closure.capture,call] at hv
    obtain ⟨source,hstep,hrel⟩ := run_reflect_core hr hk hm hready hs
    cases label <;> exact ⟨_,.cons first (.cons hstep .nil),.more first (.one hstep),hrel⟩
  · obtain ⟨source,hstep,hrel⟩ := run_reflect_core hq hk hm root hs
    exact ⟨_,step_steps hstep,.one hstep,hrel⟩

/-- 全状態について、消去後の一段を元の有限の実行へ戻す。 -/
theorem state_reflect {P B σ s t label t'} (ha : Agreement B)
    (hr : StateRel s t) (hs : Step (eraseProgram P) B σ t label t') :
    ∃ s', Steps P B σ s label.toList s' ∧ Descends P B σ s' s ∧ StateRel s' t' := by
  cases hr with
  | run hq hk hm => exact run_reflect ha hq hk hm hs
  | matchRun harms hk hm =>
    cases hs with
    | E_MatchSkip hg halt =>
      obtain ⟨guard,body,hg',_,_⟩ := harms.get_right hg
      exact ⟨_,step_steps (.E_MatchSkip hg' halt),.one (.E_MatchSkip hg' halt),.matchRun harms hk hm⟩
    | E_MatchBody hg halt =>
      obtain ⟨guard,body,hg',hb,hguard⟩ := harms.get_right hg
      cases hguard
      exact ⟨_,step_steps (.E_MatchBody hg' halt),.one (.E_MatchBody hg' halt),.run (.code hb) hk hm⟩
    | E_MatchGuard hg halt =>
      obtain ⟨guard,body,hg',hb,hguard⟩ := harms.get_right hg
      cases hguard with
      | some hc => exact ⟨_,step_steps (.E_MatchGuard hg' halt),.one (.E_MatchGuard hg' halt),
          .run (.code hc) (.cons (.guardF harms (.code hb)) hk) hm⟩
  | error hk hm =>
    cases hs with
    | E_ErrPopGuard => cases hk with
      | cons hf hk => cases hf; exact ⟨_,step_steps .E_ErrPopGuard,.one .E_ErrPopGuard,.error hk hm⟩
    | E_ErrPopLet => cases hk with
      | cons hf hk => cases hf; exact ⟨_,step_steps .E_ErrPopLet,.one .E_ErrPopLet,.error hk hm⟩
    | E_ErrPopMark => cases hk with
      | cons hf hk => cases hf; exact ⟨_,step_steps .E_ErrPopMark,.one .E_ErrPopMark,.error hk hm⟩
    | E_ErrPopUpdate => cases hk with
      | cons hf hk => cases hf; exact ⟨_,step_steps .E_ErrPopUpdate,.one .E_ErrPopUpdate,.error hk hm⟩
    | E_ErrPopHandle => cases hk with
      | cons hf hk => cases hf; exact ⟨_,step_steps .E_ErrPopHandle,.one .E_ErrPopHandle,.error hk hm⟩
    | E_ErrRel h => cases hk with
      | cons hf hk => cases hf; exact ⟨_,step_steps (.E_ErrRel h),.one (.E_ErrRel h),.error hk hm⟩
    | E_ErrRelErr h => cases hk with
      | cons hf hk => cases hf; exact ⟨_,step_steps (.E_ErrRelErr h),.one (.E_ErrRelErr h),.error hk hm⟩
    | E_ErrDrop cell =>
      obtain ⟨c,hcell,hc⟩ := hm.some_right cell
      cases hc
      cases hk with
      | cons hf hk => cases hf; exact ⟨_,step_steps (.E_ErrDrop hcell),.one (.E_ErrDrop hcell),.error hk hm⟩
    | E_ErrDropRel cell =>
      obtain ⟨c,hcell,hc⟩ := hm.some_right cell
      cases hc with
      | cont hc => cases hk with
        | cons hf hk => cases hf; exact ⟨_,step_steps (.E_ErrDropRel hcell),.one (.E_ErrDropRel hcell),.error (hc.releases.append hk) (hm.set .used)⟩
  | exit hk hm =>
    cases hs with
    | E_ExitPopGuard => cases hk with
      | cons hf hk => cases hf; exact ⟨_,step_steps .E_ExitPopGuard,.one .E_ExitPopGuard,.exit hk hm⟩
    | E_ExitPopLet => cases hk with
      | cons hf hk => cases hf; exact ⟨_,step_steps .E_ExitPopLet,.one .E_ExitPopLet,.exit hk hm⟩
    | E_ExitPopMark => cases hk with
      | cons hf hk => cases hf; exact ⟨_,step_steps .E_ExitPopMark,.one .E_ExitPopMark,.exit hk hm⟩
    | E_ExitPopUpdate => cases hk with
      | cons hf hk => cases hf; exact ⟨_,step_steps .E_ExitPopUpdate,.one .E_ExitPopUpdate,.exit hk hm⟩
    | E_ExitPopHandle => cases hk with
      | cons hf hk => cases hf; exact ⟨_,step_steps .E_ExitPopHandle,.one .E_ExitPopHandle,.exit hk hm⟩
    | E_ExitRel h => cases hk with
      | cons hf hk => cases hf; exact ⟨_,step_steps (.E_ExitRel h),.one (.E_ExitRel h),.exit hk hm⟩
    | E_ExitRelErr h => cases hk with
      | cons hf hk => cases hf; exact ⟨_,step_steps (.E_ExitRelErr h),.one (.E_ExitRelErr h),.exit hk hm⟩
    | E_ExitDrop cell =>
      obtain ⟨c,hcell,hc⟩ := hm.some_right cell
      cases hc
      cases hk with
      | cons hf hk => cases hf; exact ⟨_,step_steps (.E_ExitDrop hcell),.one (.E_ExitDrop hcell),.exit hk hm⟩
    | E_ExitDropRel cell =>
      obtain ⟨c,hcell,hc⟩ := hm.some_right cell
      cases hc with
      | cont hc => cases hk with
        | cons hf hk => cases hf; exact ⟨_,step_steps (.E_ExitDropRel hcell),.one (.E_ExitDropRel hcell),.exit (hc.releases.append hk) (hm.set .used)⟩

/-- 事象列の順を保った有限実行の連結。 -/
theorem steps_append {P B σ s t z a b} (h : Steps P B σ s a t) (g : Steps P B σ t b z) :
    Steps P B σ s (a ++ b) z := by
  induction h with
  | nil => exact g
  | @cons x label y evs z hstep hrest ih =>
    cases label <;> simpa using Steps.cons hstep (ih g)

/-- 消去後の任意の有限の実行を、同じ事象列を持つ元の実行へ戻す。 -/
theorem finite_backward {P B σ s t evs z} (ha : Agreement B) (hr : StateRel s t)
    (hs : Steps (eraseProgram P) B σ t evs z) :
    ∃ z', Steps P B σ s evs z' ∧ StateRel z' z := by
  induction hs generalizing s with
  | nil => exact ⟨_,.nil,hr⟩
  | @cons x label y evs z step rest ih =>
    obtain ⟨dest,hsteps,_,hr'⟩ := state_reflect ha hr step
    obtain ⟨z',hrest,hz⟩ := ih hr'
    refine ⟨z',?_,hz⟩
    cases label <;> exact steps_append hsteps hrest

end
end Benitoite.Release.Refinement.SafeCheckErasure
