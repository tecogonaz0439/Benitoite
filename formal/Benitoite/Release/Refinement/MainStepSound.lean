import Benitoite.Release.Refinement.MainProgress

/-! # 実行関数の健全性

設計書 01-12「確かめる性質」の実行関数 `step` について、型が付いた状態で `step` が返す遷移が関係 `Step` の遷移で
あること（計算から関係への向き）を示す。応答と新しい場所の選び方は `StepSelection` の条件だけを読む。応答の存在は
型付きの実引数と信頼条件から得る。関係のすべての遷移を `step` が返すこと（逆向き）は述べない。
-/
namespace Benitoite.Release.Refinement
noncomputable section

/-! ## ハンドラの探索の計算 -/

/-- 実行関数が見つけた分割は、関係の分割である。 -/
theorem splitHandler_split {o : OpRef} : ∀ {k k1 : Cont} {cap h k2},
    splitHandler o k = some (k1,cap,h,k2) → SplitAt o k k1 cap h k2
  | [], _, _, _, _, hs => by simp [splitHandler] at hs
  | f :: k, k1, cap, h, k2, hs => by
    cases f
    case handleF cap' h' =>
      by_cases hh : handles h' o = true
      · simp only [splitHandler,hh,↓reduceIte,Option.some.injEq,Prod.mk.injEq] at hs
        obtain ⟨rfl,rfl,rfl,rfl⟩ := hs
        exact ⟨rfl,hh,fun _ _ hin => by simp at hin⟩
      · simp only [splitHandler,hh,Bool.false_eq_true,↓reduceIte,Option.map_eq_some_iff] at hs
        obtain ⟨⟨k1',cap'',h'',k2'⟩,hs',he⟩ := hs
        simp only [Prod.mk.injEq] at he
        obtain ⟨rfl,rfl,rfl,rfl⟩ := he
        obtain ⟨hk,hh',hn⟩ := splitHandler_split hs'
        refine ⟨by rw [hk]; rfl,hh',fun c cs hin => ?_⟩
        rcases List.mem_cons.mp hin with e | hin
        · cases e; simpa using hh
        · exact hn c cs hin
    all_goals
      simp only [splitHandler,Option.map_eq_some_iff] at hs
      obtain ⟨⟨k1',cap'',h'',k2'⟩,hs',he⟩ := hs
      simp only [Prod.mk.injEq] at he
      obtain ⟨rfl,rfl,rfl,rfl⟩ := he
      obtain ⟨hk,hh',hn⟩ := splitHandler_split hs'
      refine ⟨by rw [hk]; rfl,hh',fun c cs hin => ?_⟩
      rcases List.mem_cons.mp hin with e | hin
      · cases e
      · exact hn c cs hin

/-- 実行関数が分割を見つけないなら、どの枠も処理しない。 -/
theorem splitHandler_noHandler {o : OpRef} : ∀ {k : Cont}, splitHandler o k = none → NoHandler k o
  | [], _ => fun _ _ hin => by simp at hin
  | f :: k, hs => by
    cases f
    case handleF cap' h' =>
      by_cases hh : handles h' o = true
      · simp [splitHandler,hh] at hs
      · simp only [splitHandler,hh,Bool.false_eq_true,↓reduceIte,Option.map_eq_none_iff] at hs
        have hn := splitHandler_noHandler hs
        intro c cs hin
        rcases List.mem_cons.mp hin with e | hin
        · cases e; simpa using hh
        · exact hn c cs hin
    all_goals
      simp only [splitHandler,Option.map_eq_none_iff] at hs
      have hn := splitHandler_noHandler hs
      intro c cs hin
      rcases List.mem_cons.mp hin with e | hin
      · cases e
      · exact hn c cs hin

/-! ## run の状態 -/

private theorem release_selected {P B σ Ψ R e k a b Eb Re v} {rel : Val → Option ErrKind}
    (hB : B.CoreAssumptions P) (hrel : ∀ v r, B.releaseResponse v r → B.releaseResponse v (rel v))
    (hk : ContTy P B σ Ψ R e (.release v :: k) a b Eb Re) : B.releaseResponse v (rel v) := by
  obtain ⟨r,hr⟩ := hk.release_response_exists hB
  exact hrel v r hr

/-- run の状態で実行関数が返す遷移は関係の遷移である。 -/
theorem StateTyE.run_step_sound {P B σ Eb oracle externalOracle rel fresh q k μ l s'}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hsel : StepSelection B oracle externalOracle rel fresh)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hstep : step P B σ oracle externalOracle rel fresh (.run q k μ) = some (l,s')) :
    Step P B σ (.run q k μ) l s' := by
  have hparts := h
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,hsub,hk,had,hcl,hkc,hμ⟩ := hparts
  have hfresh : μ (fresh μ) = none := hsel.fresh μ hs.finite
  change stepRun P B σ oracle externalOracle rel fresh q q.view k μ = some (l,s') at hstep
  generalize hv : q.view = c at hstep
  cases c with
  | builderLet kind body =>
    simp only [stepRun,Option.some.injEq,Prod.mk.injEq] at hstep
    obtain ⟨rfl,rfl⟩ := hstep
    exact .E_BuilderNew hv hfresh
  | builderOp kind op r args =>
    cases r with
    | bound i => simp [stepRun] at hstep
    | loc l0 =>
      simp only [stepRun] at hstep
      cases hc : μ l0 with
      | none => simp [hc] at hstep
      | some cell =>
        cases cell with
        | builder c =>
          simp only [hc] at hstep
          cases hr : builderApply op c args with
          | none => simp [hr] at hstep
          | some reply =>
            cases reply with
            | value c' v =>
              simp only [hr,Option.some.injEq,Prod.mk.injEq] at hstep
              obtain ⟨rfl,rfl⟩ := hstep
              exact .E_BuilderOp hv hc hr
            | error r =>
              simp only [hr,Option.some.injEq,Prod.mk.injEq] at hstep
              obtain ⟨rfl,rfl⟩ := hstep
              exact .E_BuilderErr hv hc hr
        | _ => simp [hc] at hstep
  | ret v =>
    cases k with
    | nil => simp [stepRun] at hstep
    | cons f k =>
      cases f with
      | letF n =>
        simp only [stepRun,Option.some.injEq,Prod.mk.injEq] at hstep
        obtain ⟨rfl,rfl⟩ := hstep
        exact .E_Return hv
      | mark =>
        simp only [stepRun,Option.some.injEq,Prod.mk.injEq] at hstep
        obtain ⟨rfl,rfl⟩ := hstep
        exact .E_Mark hv
      | update l0 =>
        simp only [stepRun,Option.some.injEq,Prod.mk.injEq] at hstep
        obtain ⟨rfl,rfl⟩ := hstep
        exact .E_Update hv
      | release w =>
        have hr := release_selected hB hsel.release hk
        simp only [stepRun,releaseStep] at hstep
        cases hrv : rel w with
        | none =>
          simp only [hrv,Option.some.injEq,Prod.mk.injEq] at hstep
          obtain ⟨rfl,rfl⟩ := hstep
          rw [hrv] at hr
          exact .E_Release hv hr
        | some r =>
          simp only [hrv,Option.some.injEq,Prod.mk.injEq] at hstep
          obtain ⟨rfl,rfl⟩ := hstep
          rw [hrv] at hr
          exact .E_RelErr hv hr
      | handleF cap cs =>
        simp only [stepRun,Option.some.injEq,Prod.mk.injEq] at hstep
        obtain ⟨rfl,rfl⟩ := hstep
        exact .E_HRet hv
      | drop κ =>
        simp only [stepRun] at hstep
        cases hc : μ κ with
        | none => simp [hc] at hstep
        | some cell =>
          cases cell with
          | used =>
            simp only [hc,Option.some.injEq,Prod.mk.injEq] at hstep
            obtain ⟨rfl,rfl⟩ := hstep
            exact .E_Drop hv hc
          | cont k' =>
            simp only [hc,Option.some.injEq,Prod.mk.injEq] at hstep
            obtain ⟨rfl,rfl⟩ := hstep
            exact .E_DropRel hv hc
          | _ => simp [hc] at hstep
      | guardF w cap arms next body =>
        cases v
        all_goals try (simp [stepRun] at hstep; done)
        rename_i c
        cases c
        all_goals try (simp [stepRun] at hstep; done)
        rename_i bv
        cases bv
        · simp only [stepRun,Option.some.injEq,Prod.mk.injEq] at hstep
          obtain ⟨rfl,rfl⟩ := hstep
          exact .E_GuardF hv
        · simp only [stepRun,Option.some.injEq,Prod.mk.injEq] at hstep
          obtain ⟨rfl,rfl⟩ := hstep
          exact .E_GuardT hv
  | letIn m n =>
    simp only [stepRun,Option.some.injEq,Prod.mk.injEq] at hstep
    obtain ⟨rfl,rfl⟩ := hstep
    exact .E_Let hv
  | «match» v arms =>
    simp only [stepRun,Option.some.injEq,Prod.mk.injEq] at hstep
    obtain ⟨rfl,rfl⟩ := hstep
    exact .E_Match hv
  | lazyC m =>
    simp only [stepRun,Option.some.injEq,Prod.mk.injEq] at hstep
    obtain ⟨rfl,rfl⟩ := hstep
    exact .E_Lazy hv hfresh
  | use v m =>
    simp only [stepRun,Option.some.injEq,Prod.mk.injEq] at hstep
    obtain ⟨rfl,rfl⟩ := hstep
    exact .E_Use hv
  | handle m cs =>
    simp only [stepRun,Option.some.injEq,Prod.mk.injEq] at hstep
    obtain ⟨rfl,rfl⟩ := hstep
    exact .E_Handle hv
  | ite v m n =>
    cases v
    all_goals try (simp [stepRun] at hstep; done)
    rename_i c
    cases c
    all_goals try (simp [stepRun] at hstep; done)
    rename_i bv
    cases bv
    · simp only [stepRun,Option.some.injEq,Prod.mk.injEq] at hstep
      obtain ⟨rfl,rfl⟩ := hstep
      exact .E_IfF hv
    · simp only [stepRun,Option.some.injEq,Prod.mk.injEq] at hstep
      obtain ⟨rfl,rfl⟩ := hstep
      exact .E_IfT hv
  | escape v =>
    cases k with
    | nil => simp [stepRun] at hstep
    | cons f k =>
      cases f with
      | letF n =>
        simp only [stepRun,Option.some.injEq,Prod.mk.injEq] at hstep
        obtain ⟨rfl,rfl⟩ := hstep
        exact .E_EscLet hv
      | mark =>
        simp only [stepRun,Option.some.injEq,Prod.mk.injEq] at hstep
        obtain ⟨rfl,rfl⟩ := hstep
        exact .E_EscMark hv
      | handleF cap cs =>
        simp only [stepRun,Option.some.injEq,Prod.mk.injEq] at hstep
        obtain ⟨rfl,rfl⟩ := hstep
        exact .E_EscHandle hv
      | release w =>
        have hr := release_selected hB hsel.release hk
        simp only [stepRun,releaseStep] at hstep
        cases hrv : rel w with
        | none =>
          simp only [hrv,Option.some.injEq,Prod.mk.injEq] at hstep
          obtain ⟨rfl,rfl⟩ := hstep
          rw [hrv] at hr
          exact .E_EscRel hv hr
        | some r =>
          simp only [hrv,Option.some.injEq,Prod.mk.injEq] at hstep
          obtain ⟨rfl,rfl⟩ := hstep
          rw [hrv] at hr
          exact .E_EscRelErr hv hr
      | drop κ =>
        simp only [stepRun] at hstep
        cases hc : μ κ with
        | none => simp [hc] at hstep
        | some cell =>
          cases cell with
          | used =>
            simp only [hc,Option.some.injEq,Prod.mk.injEq] at hstep
            obtain ⟨rfl,rfl⟩ := hstep
            exact .E_EscDrop hv hc
          | cont k' =>
            simp only [hc,Option.some.injEq,Prod.mk.injEq] at hstep
            obtain ⟨rfl,rfl⟩ := hstep
            exact .E_EscDropRel hv hc
          | _ => simp [hc] at hstep
      | update l0 => simp [stepRun] at hstep
      | guardF w cap arms next body => simp [stepRun] at hstep
  | resume w v =>
    cases w
    all_goals try (simp [stepRun] at hstep; done)
    rename_i κ
    simp only [stepRun] at hstep
    cases hc : μ κ with
    | none => simp [hc] at hstep
    | some cell =>
      cases cell with
      | cont k' =>
        simp only [hc,Option.some.injEq,Prod.mk.injEq] at hstep
        obtain ⟨rfl,rfl⟩ := hstep
        exact .E_Resume hv hc
      | used =>
        simp only [hc,Option.some.injEq,Prod.mk.injEq] at hstep
        obtain ⟨rfl,rfl⟩ := hstep
        exact .E_ResumeErr hv hc
      | _ => simp [hc] at hstep
  | externalCall f ts ws =>
    obtain ⟨out,obs,_,hresp,_⟩ := h.external_response_step hP hPB hB hv
    have hsel' := hsel.external f ts ws out obs hresp
    simp only [stepRun] at hstep
    cases hd : P.externalFunction f with
    | none => simp [hd,-Ty.normTys_eq_map] at hstep
    | some d =>
      simp only [hd] at hstep
      cases hrecv : externalReceive P d ts ws (externalOracle f ts ws).1 with
      | none => simp [hrecv] at hstep
      | some o =>
        cases o with
        | val v =>
          simp only [hrecv,Option.some.injEq,Prod.mk.injEq] at hstep
          obtain ⟨rfl,rfl⟩ := hstep
          exact .E_External hv hd hsel' hrecv
        | err r =>
          simp only [hrecv,Option.some.injEq,Prod.mk.injEq] at hstep
          obtain ⟨rfl,rfl⟩ := hstep
          exact .E_ExternalErr hv hd hsel' hrecv
        | exit n => simp [hrecv] at hstep
  | issuePathBases b0 =>
    simp only [stepRun] at hstep
    cases hsig : B.sig b0 with
    | none => simp [hsig] at hstep
    | some sg =>
      simp only [hsig] at hstep
      split at hstep
      · rename_i hc
        obtain ⟨hk',hop,hσ⟩ := hc
        simp only [Option.some.injEq,Prod.mk.injEq] at hstep
        obtain ⟨rfl,rfl⟩ := hstep
        exact .E_IssuePathBases hv hsig hk' hop hσ
      · simp at hstep
  | checkAt kind name shape bases pattern input index =>
    simp only [stepRun] at hstep
    cases hcode : q.code with
    | checkAt kind' name' shape' bases' pattern' input' index' =>
      simp only [hcode] at hstep
      cases hprep : AtPrepare B q.capture kind' name' bases' pattern' input' index' with
      | error detail =>
        simp only [hprep,Option.some.injEq,Prod.mk.injEq] at hstep
        obtain ⟨rfl,rfl⟩ := hstep
        exact .E_AtPrepareError hcode hprep
      | ok res =>
        obtain ⟨snapshot,pat,target,bound⟩ := res
        simp only [hprep] at hstep
        have finish : (∀ ρ, snapshot = some ρ → ρ = σ) →
            (match checkAt snapshot kind' pat target bound with
              | .ok t => some (none, State.run (Closure.pure (.ret
                  (.con shape'.ok [.scoped name' kind' (.fixed bound), q.capture.closeTy shape'.errorType]
                    [.checkedAt bound snapshot t (AtRequest B name' (closeVal q.capture input'))]))) k μ)
              | .error detail => some (none, State.run (Closure.pure (.ret
                  (.con shape'.error [.scoped name' kind' (.fixed bound), q.capture.closeTy shape'.errorType]
                    [.atError (AtError.fromCheck (closeVal q.capture pattern') (closeVal q.capture input')
                      snapshot pat target detail)]))) k μ)) = some (l,s') →
            Step P B σ (.run q k μ) l s' := by
          intro hcur he
          cases hcheck : checkAt snapshot kind' pat target bound with
          | ok t =>
            simp only [hcheck,Option.some.injEq,Prod.mk.injEq] at he
            obtain ⟨rfl,rfl⟩ := he
            exact .E_AtOk hcode hprep hcur hcheck
          | error d =>
            simp only [hcheck,Option.some.injEq,Prod.mk.injEq] at he
            obtain ⟨rfl,rfl⟩ := he
            exact .E_AtError hcode hprep hcur hcheck
        cases snapshot with
        | none =>
          rw [ite_eq_left_of_eq_true _ _ (by simp)] at hstep
          exact finish (by intro ρ hρ; cases hρ) hstep
        | some ρ =>
          by_cases hρ : ρ = σ
          · subst hρ
            rw [ite_eq_left_of_eq_true _ _ (by simp)] at hstep
            exact finish (by intro ρ' hρ'; cases hρ'; rfl) hstep
          · simp [hρ] at hstep
    | _ => simp [hcode] at hstep
  | meth v m ss es ws =>
    cases v with
    | dict i ts vs =>
      simp only [stepRun] at hstep
      cases hi : P.impls i with
      | none => simp [hi] at hstep
      | some id =>
        simp only [hi] at hstep
        cases hb : id.methods m with
        | none => simp [hb] at hstep
        | some body =>
          cases hcl : P.classes id.cls with
          | none => simp [hb,hcl] at hstep
          | some cd =>
            simp only [hb,hcl] at hstep
            cases hms : cd.methods m with
            | none => simp [hms] at hstep
            | some ms =>
              simp only [hms] at hstep
              split at hstep
              · rename_i hlen
                obtain ⟨h1,h2,h3,h4,h5⟩ := hlen
                simp only [Option.some.injEq,Prod.mk.injEq] at hstep
                obtain ⟨rfl,rfl⟩ := hstep
                exact .E_Meth hv hi hb hcl hms h1 h2 h3 h4 h5
              · simp at hstep
    | _ =>
      simp only [stepRun,Option.map_eq_some_iff,Prod.mk.injEq] at hstep
      obtain ⟨v',hv',rfl,rfl⟩ := hstep
      exact .E_Super hv hv'
  | app f ws =>
    cases f
    all_goals try (simp [stepRun] at hstep; done)
    case fnRef g ts es ranges =>
      cases hrs : closedRanges ranges with
      | none => simp [stepRun,hrs] at hstep
      | some rs =>
        have heq := (closedRanges_eq_some ranges rs).mp hrs
        subst ranges
        simp only [stepRun,closedRanges_fixed] at hstep
        cases hd : P.defs g with
        | none => simp [hd,-Ty.normTys_eq_map] at hstep
        | some d =>
          simp only [hd] at hstep
          split at hstep
          · rename_i hlen
            obtain ⟨h1,h2,h3⟩ := hlen
            simp only [Option.some.injEq,Prod.mk.injEq] at hstep
            obtain ⟨rfl,rfl⟩ := hstep
            exact .E_Fun hv hd h1 h2 h3
          · simp at hstep
    case externalRef g ts =>
      simp only [stepRun,Option.some.injEq,Prod.mk.injEq] at hstep
      obtain ⟨rfl,rfl⟩ := hstep
      exact .E_ExternalApply hv
    case op o ts =>
      simp only [stepRun] at hstep
      cases hsp : splitHandler (.user o) k with
      | none => simp [hsp] at hstep
      | some x =>
        obtain ⟨k1,hcap,cs,k2⟩ := x
        simp only [hsp] at hstep
        cases hc : findClause cs (.user o) with
        | none => simp [hc] at hstep
        | some c =>
          simp only [hc,Option.some.injEq,Prod.mk.injEq] at hstep
          obtain ⟨rfl,rfl⟩ := hstep
          exact .E_Op hv (splitHandler_split hsp) hc hfresh
    case raise t e0 =>
      rcases ws with _ | ⟨w,_ | ⟨w',ws⟩⟩
      · simp [stepRun] at hstep
      · simp only [stepRun] at hstep
        cases hsp : splitHandler .fail k with
        | none => simp [hsp] at hstep
        | some x =>
          obtain ⟨k1,hcap,cs,k2⟩ := x
          rcases cs with _ | ⟨c,_ | ⟨c',cs⟩⟩
          · simp [hsp] at hstep
          · cases c with
            | fail err body =>
              simp only [hsp,Option.some.injEq,Prod.mk.injEq] at hstep
              obtain ⟨rfl,rfl⟩ := hstep
              exact .E_OpFail hv (splitHandler_split hsp) hfresh
            | mk _ _ _ _ => simp [hsp] at hstep
          · simp [hsp] at hstep
      · simp [stepRun] at hstep
    case lam ns ps body =>
      simp only [stepRun] at hstep
      split at hstep
      · rename_i sig bd hc
        split at hstep
        · rename_i hlen
          simp only [Option.some.injEq,Prod.mk.injEq] at hstep
          obtain ⟨rfl,rfl⟩ := hstep
          exact .E_Lam hv hc hlen
        · simp at hstep
      · simp at hstep
    case dependentLam t body =>
      simp only [stepRun] at hstep
      split at hstep
      · rename_i sig bd hc
        split at hstep
        · rename_i hlen
          simp only [Option.some.injEq,Prod.mk.injEq] at hstep
          obtain ⟨rfl,rfl⟩ := hstep
          exact .E_Lam hv hc hlen
        · simp at hstep
      · simp at hstep
    case closure t body =>
      simp only [stepRun] at hstep
      split at hstep
      · rename_i sig bd hc
        split at hstep
        · rename_i hlen
          simp only [Option.some.injEq,Prod.mk.injEq] at hstep
          obtain ⟨rfl,rfl⟩ := hstep
          exact .E_Lam hv hc hlen
        · simp at hstep
      · simp at hstep
    case prim b ts es rangeArgs =>
      have hg := hq.view_read_ground hcl (v := .prim b ts es rangeArgs)
        (by rw [hv]; exact List.mem_cons_self)
      have hrs : ∀ ix ∈ rangeArgs, ix.WF 0 := fun ix hx => (hg.2.2 ix hx).1
      obtain ⟨rs, rfl⟩ := fixed_ranges_of_wf0 hrs
      simp only [stepRun, closedRanges_fixed] at hstep
      cases hsig : B.sig b with
      | none => simp [hsig] at hstep
      | some sg =>
        simp only [hsig] at hstep
        obtain ⟨r,ef,hargs,_,_⟩ := hq.primitive_view_inputs hP hPB hB hs.wf hs.sorted hs.declared hcl hv hsig
        have handled : (sg.kind = .io ∨ sg.kind = .exit) →
            ∀ {x}, splitHandler (.prim b) k = some x →
            (match findClause x.2.2.1 (.prim b) with
              | some c => some (none, State.run (Closure.mk (x.2.1.extendMany (ws ++ [.loc (fresh μ)]))
                  (c.body.substTy ts [])) (.drop (fresh μ) :: x.2.2.2)
                  (μ.set (fresh μ) (.cont (x.1 ++ [.handleF x.2.1 x.2.2.1]))))
              | none => none) = some (l,s') → Step P B σ (.run q k μ) l s' := by
          intro hk x hsp hm
          obtain ⟨k1,hcap,cs,k2⟩ := x
          cases hc : findClause cs (.prim b) with
          | none => simp [hc] at hm
          | some c =>
            simp only [hc,Option.some.injEq,Prod.mk.injEq] at hm
            obtain ⟨rfl,rfl⟩ := hm
            exact .E_OpPrim hv hsig hk (splitHandler_split hsp) hc hfresh
        have ioResp : (sg.kind = .io ∨ sg.kind = .exit) →
            B.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws
              (oracle b (Ty.normTys ts) (es.map Eff.norm) ws).1 (oracle b (Ty.normTys ts) (es.map Eff.norm) ws).2 := by
          intro hk
          obtain ⟨out0,obs0,hex⟩ := hB.io_exists Ψ b sg _ _ rs ws r ef hsig hk hargs
          exact hsel.io b _ _ ws out0 obs0 hex
        cases hkind : sg.kind with
        | pure =>
          simp only [hkind] at hstep
          cases hd : B.delta b (Ty.normTys ts) (es.map Eff.norm) rs ws with
          | none => simp [hd,-Ty.normTys_eq_map] at hstep
          | some o =>
            cases o with
            | val v =>
              simp only [hd,Option.some.injEq,Prod.mk.injEq] at hstep
              obtain ⟨rfl,rfl⟩ := hstep
              exact .E_Prim hv hsig hkind hd
            | err rr =>
              simp only [hd,Option.some.injEq,Prod.mk.injEq] at hstep
              obtain ⟨rfl,rfl⟩ := hstep
              exact .E_Err hv hsig hkind hd
            | exit n => simp [hd,-Ty.normTys_eq_map] at hstep
        | io =>
          simp only [hkind] at hstep
          cases hsp : splitHandler (.prim b) k with
          | some x =>
            simp only [hsp] at hstep
            exact handled (.inl hkind) hsp hstep
          | none =>
            have hno := splitHandler_noHandler hsp
            have hresp := ioResp (.inl hkind)
            simp only [hsp] at hstep
            cases ho : oracle b (Ty.normTys ts) (es.map Eff.norm) ws with
            | mk out obs =>
              rw [ho] at hresp
              cases out with
              | val v =>
                simp [ho,-Ty.normTys_eq_map] at hstep
                obtain ⟨rfl,rfl⟩ := hstep
                exact .E_IO hv hsig hkind hno hresp
              | err rr =>
                simp [ho,-Ty.normTys_eq_map] at hstep
                obtain ⟨rfl,rfl⟩ := hstep
                exact .E_IOErr hv hsig (.inl hkind) hno hresp
              | exit n => simp [ho,-Ty.normTys_eq_map] at hstep
        | exit =>
          simp only [hkind] at hstep
          cases hsp : splitHandler (.prim b) k with
          | some x =>
            simp only [hsp] at hstep
            exact handled (.inr hkind) hsp hstep
          | none =>
            have hno := splitHandler_noHandler hsp
            have hresp := ioResp (.inr hkind)
            simp only [hsp] at hstep
            cases ho : oracle b (Ty.normTys ts) (es.map Eff.norm) ws with
            | mk out obs =>
              rw [ho] at hresp
              cases out with
              | val v => simp [ho,-Ty.normTys_eq_map] at hstep
              | err rr =>
                simp [ho,-Ty.normTys_eq_map] at hstep
                obtain ⟨rfl,rfl⟩ := hstep
                exact .E_IOErr hv hsig (.inr hkind) hno hresp
              | exit n =>
                simp [ho,-Ty.normTys_eq_map] at hstep
                obtain ⟨rfl,rfl⟩ := hstep
                exact .E_Exit hv hsig hkind hno hresp
        | pathBases =>
          simp only [hkind] at hstep
          split at hstep
          · rename_i hemp
            simp only [Bool.and_eq_true,List.isEmpty_iff] at hemp
            obtain ⟨⟨⟨rfl,rfl⟩,rfl⟩,rfl⟩ := hemp
            simp only [Option.some.injEq,Prod.mk.injEq] at hstep
            obtain ⟨rfl,rfl⟩ := hstep
            exact .E_PathBasesApply hv hsig hkind
          · simp at hstep
        | refNew =>
          rcases ws with _ | ⟨w,_ | ⟨w',ws⟩⟩
          · simp [hkind] at hstep
          · simp only [hkind,Option.some.injEq,Prod.mk.injEq] at hstep
            obtain ⟨rfl,rfl⟩ := hstep
            exact .E_RefNew hv hsig hkind hfresh
          · simp [hkind] at hstep
        | refGet =>
          rcases ws with _ | ⟨w,_ | ⟨w',ws⟩⟩
          · simp [hkind] at hstep
          · cases w
            all_goals try (simp [hkind] at hstep; done)
            rename_i l0
            simp only [hkind] at hstep
            cases hc : μ l0 with
            | none => simp [hc] at hstep
            | some cell =>
              cases cell with
              | val v =>
                simp only [hc,Option.some.injEq,Prod.mk.injEq] at hstep
                obtain ⟨rfl,rfl⟩ := hstep
                exact .E_RefGet hv hsig hkind hc
              | _ => simp [hc] at hstep
          · simp [hkind] at hstep
        | refSet =>
          rcases ws with _ | ⟨w,_ | ⟨v,_ | ⟨w',ws⟩⟩⟩
          · simp [hkind] at hstep
          · simp [hkind] at hstep
          · cases w
            all_goals try (simp [hkind] at hstep; done)
            simp only [hkind,Option.some.injEq,Prod.mk.injEq] at hstep
            obtain ⟨rfl,rfl⟩ := hstep
            exact .E_RefSet hv hsig hkind
          · simp [hkind] at hstep
        | refUpdate =>
          rcases ws with _ | ⟨w,_ | ⟨v,_ | ⟨w',ws⟩⟩⟩
          · simp [hkind] at hstep
          · simp [hkind] at hstep
          · cases w
            all_goals try (simp [hkind] at hstep; done)
            simp only [hkind,Option.some.injEq,Prod.mk.injEq] at hstep
            obtain ⟨rfl,rfl⟩ := hstep
            exact .E_RefUpdate hv hsig hkind
          · simp [hkind] at hstep
        | force =>
          rcases ws with _ | ⟨w,_ | ⟨w',ws⟩⟩
          · simp [hkind] at hstep
          · cases w
            all_goals try (simp [hkind] at hstep; done)
            rename_i l0
            simp only [hkind] at hstep
            cases hc : μ l0 with
            | none => simp [hc] at hstep
            | some cell =>
              cases cell with
              | done v =>
                simp only [hc,Option.some.injEq,Prod.mk.injEq] at hstep
                obtain ⟨rfl,rfl⟩ := hstep
                exact .E_ForceDone hv hsig hkind hc
              | thunk m =>
                simp only [hc,Option.some.injEq,Prod.mk.injEq] at hstep
                obtain ⟨rfl,rfl⟩ := hstep
                exact .E_Force hv hsig hkind hc
              | _ => simp [hc] at hstep
          · simp [hkind] at hstep

/-! ## 照合・失敗・終了の状態 -/

/-- 照合の途中の状態で実行関数が返す遷移は関係の遷移である。 -/
theorem match_step_sound {P B σ oracle externalOracle rel fresh v cap arms next k μ l s'}
    (hstep : step P B σ oracle externalOracle rel fresh (.matchRun v cap arms next k μ) = some (l,s')) :
    Step P B σ (.matchRun v cap arms next k μ) l s' := by
  change stepMatch v cap arms next k μ = some (l,s') at hstep
  unfold stepMatch at hstep
  cases ha : arms[next]? with
  | none => simp [ha] at hstep
  | some arm =>
    obtain ⟨alts,guard,body⟩ := arm
    simp only [ha] at hstep
    cases hf : firstAlt v alts with
    | none =>
      simp only [hf,Option.some.injEq,Prod.mk.injEq] at hstep
      obtain ⟨rfl,rfl⟩ := hstep
      exact .E_MatchSkip ha hf
    | some ws =>
      cases guard with
      | none =>
        simp only [hf,Option.some.injEq,Prod.mk.injEq] at hstep
        obtain ⟨rfl,rfl⟩ := hstep
        exact .E_MatchBody ha hf
      | some g =>
        simp only [hf,Option.some.injEq,Prod.mk.injEq] at hstep
        obtain ⟨rfl,rfl⟩ := hstep
        exact .E_MatchGuard ha hf

/-- 失敗の状態で実行関数が返す遷移は関係の遷移である。 -/
theorem StateTyE.error_step_sound {P B σ Eb oracle externalOracle rel fresh rs k μ l s'}
    (hB : B.CoreAssumptions P) (hsel : StepSelection B oracle externalOracle rel fresh)
    (h : StateTyE P B σ Eb (.error rs k μ))
    (hstep : step P B σ oracle externalOracle rel fresh (.error rs k μ) = some (l,s')) :
    Step P B σ (.error rs k μ) l s' := by
  obtain ⟨Ψ,R,a,b,e,hs,hk,_⟩ := h
  cases k with
  | nil => simp [step] at hstep
  | cons f k =>
    cases f with
    | release w =>
      have hr := release_selected hB hsel.release hk
      simp only [step,releaseStep] at hstep
      cases hrv : rel w with
      | none =>
        simp only [hrv,Option.some.injEq,Prod.mk.injEq] at hstep
        obtain ⟨rfl,rfl⟩ := hstep
        rw [hrv] at hr
        exact .E_ErrRel hr
      | some r =>
        simp only [hrv,Option.some.injEq,Prod.mk.injEq] at hstep
        obtain ⟨rfl,rfl⟩ := hstep
        rw [hrv] at hr
        exact .E_ErrRelErr hr
    | drop κ =>
      simp only [step] at hstep
      cases hc : μ κ with
      | none => simp [hc] at hstep
      | some cell =>
        cases cell with
        | used =>
          simp only [hc,Option.some.injEq,Prod.mk.injEq] at hstep
          obtain ⟨rfl,rfl⟩ := hstep
          exact .E_ErrDrop hc
        | cont k' =>
          simp only [hc,Option.some.injEq,Prod.mk.injEq] at hstep
          obtain ⟨rfl,rfl⟩ := hstep
          exact .E_ErrDropRel hc
        | _ => simp [hc] at hstep
    | letF n =>
      simp only [step,Option.some.injEq,Prod.mk.injEq] at hstep
      obtain ⟨rfl,rfl⟩ := hstep
      exact .E_ErrPopLet
    | mark =>
      simp only [step,Option.some.injEq,Prod.mk.injEq] at hstep
      obtain ⟨rfl,rfl⟩ := hstep
      exact .E_ErrPopMark
    | update l0 =>
      simp only [step,Option.some.injEq,Prod.mk.injEq] at hstep
      obtain ⟨rfl,rfl⟩ := hstep
      exact .E_ErrPopUpdate
    | handleF cap cs =>
      simp only [step,Option.some.injEq,Prod.mk.injEq] at hstep
      obtain ⟨rfl,rfl⟩ := hstep
      exact .E_ErrPopHandle
    | guardF w cap arms next body =>
      simp only [step,Option.some.injEq,Prod.mk.injEq] at hstep
      obtain ⟨rfl,rfl⟩ := hstep
      exact .E_ErrPopGuard

/-- 終了の状態で実行関数が返す遷移は関係の遷移である。 -/
theorem StateTyE.exit_step_sound {P B σ Eb oracle externalOracle rel fresh n rs k μ l s'}
    (hB : B.CoreAssumptions P) (hsel : StepSelection B oracle externalOracle rel fresh)
    (h : StateTyE P B σ Eb (.exit n rs k μ))
    (hstep : step P B σ oracle externalOracle rel fresh (.exit n rs k μ) = some (l,s')) :
    Step P B σ (.exit n rs k μ) l s' := by
  obtain ⟨Ψ,R,a,b,e,hs,hk,_⟩ := h
  cases k with
  | nil => simp [step] at hstep
  | cons f k =>
    cases f with
    | release w =>
      have hr := release_selected hB hsel.release hk
      simp only [step,releaseStep] at hstep
      cases hrv : rel w with
      | none =>
        simp only [hrv,Option.some.injEq,Prod.mk.injEq] at hstep
        obtain ⟨rfl,rfl⟩ := hstep
        rw [hrv] at hr
        exact .E_ExitRel hr
      | some r =>
        simp only [hrv,Option.some.injEq,Prod.mk.injEq] at hstep
        obtain ⟨rfl,rfl⟩ := hstep
        rw [hrv] at hr
        exact .E_ExitRelErr hr
    | drop κ =>
      simp only [step] at hstep
      cases hc : μ κ with
      | none => simp [hc] at hstep
      | some cell =>
        cases cell with
        | used =>
          simp only [hc,Option.some.injEq,Prod.mk.injEq] at hstep
          obtain ⟨rfl,rfl⟩ := hstep
          exact .E_ExitDrop hc
        | cont k' =>
          simp only [hc,Option.some.injEq,Prod.mk.injEq] at hstep
          obtain ⟨rfl,rfl⟩ := hstep
          exact .E_ExitDropRel hc
        | _ => simp [hc] at hstep
    | letF m =>
      simp only [step,Option.some.injEq,Prod.mk.injEq] at hstep
      obtain ⟨rfl,rfl⟩ := hstep
      exact .E_ExitPopLet
    | mark =>
      simp only [step,Option.some.injEq,Prod.mk.injEq] at hstep
      obtain ⟨rfl,rfl⟩ := hstep
      exact .E_ExitPopMark
    | update l0 =>
      simp only [step,Option.some.injEq,Prod.mk.injEq] at hstep
      obtain ⟨rfl,rfl⟩ := hstep
      exact .E_ExitPopUpdate
    | handleF cap cs =>
      simp only [step,Option.some.injEq,Prod.mk.injEq] at hstep
      obtain ⟨rfl,rfl⟩ := hstep
      exact .E_ExitPopHandle
    | guardF w cap arms next body =>
      simp only [step,Option.some.injEq,Prod.mk.injEq] at hstep
      obtain ⟨rfl,rfl⟩ := hstep
      exact .E_ExitPopGuard

/-- 実行関数の健全性。型が付いた状態について、選択の条件を満たす実行関数が返す遷移は関係の遷移である。 -/
theorem StateTyE.step_sound {P B σ Eb oracle externalOracle rel fresh s l s'}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hsel : StepSelection B oracle externalOracle rel fresh) (h : StateTyE P B σ Eb s)
    (hstep : step P B σ oracle externalOracle rel fresh s = some (l,s')) :
    Step P B σ s l s' := by
  cases s with
  | run q k μ => exact h.run_step_sound hP hPB hB hsel hstep
  | matchRun v cap arms next k μ => exact match_step_sound hstep
  | error rs k μ => exact h.error_step_sound hB hsel hstep
  | exit n rs k μ => exact h.exit_step_sound hB hsel hstep

end
end Benitoite.Release.Refinement
