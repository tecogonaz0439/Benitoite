import Benitoite.Release.Refinement.MainStatements
import Benitoite.Release.Refinement.FiniteStepPreservation
import Benitoite.Release.Refinement.ControlLeafSelection
import Benitoite.Release.Refinement.AtTargets
import Benitoite.Release.Refinement.ExternalLeafSelection
import Benitoite.Release.Refinement.TypedCoverage
import Benitoite.Release.Refinement.CanonicalValues
import Benitoite.Release.Refinement.LazyInversion
import Benitoite.Release.Refinement.HandlerTyping
import Benitoite.Release.Refinement.MatchFacts

/-! # 進行

設計書 01-12「確かめる性質」の性質 2 のうち進行を、篩付きの型の判断の状態の型付けについて示す。型が付いた状態は終端で
あるか遷移を持つ。継続の末尾の効果が組み込みの効果だけであることから、どの `handle` の枠も処理しない利用者の操作と
失敗は起きない。
-/
namespace Benitoite.Release.Refinement
noncomputable section

/-! ## 継続の枠の逆転 -/

/-- drop の枠が指す場所は継続の場所の型を持つ。 -/
theorem ContTy.drop_cell {P B σ Ψ R ε l k a b Eb Re}
    (h : ContTy P B σ Ψ R ε (.drop l :: k) a b Eb Re) :
    ∃ b' t' e' r', Ψ l = some (.cont b' t' e' r') := by
  generalize hk : Frame.drop l :: k = ks at h
  induction h with
  | K_Drop hl _ _ _ => cases hk; exact ⟨_,_,_,_,hl⟩
  | K_Sub _ _ ih => exact ih hk
  | _ => cases hk

/-- guard の枠へ返す閉じた値は真偽の定数である。 -/
theorem ContTy.guard_boolean {P B σ Ψ R ε v cap arms next body k a b Eb Re w x}
    (h : ContTy P B σ Ψ R ε (.guardF v cap arms next body :: k) a b Eb Re)
    (hw : HasTypeVQ P B Ψ Qempty [] [] [] w x) (hle : Ty.LeQ P [] [] x a) :
    ∃ c, w = .const (.boolean c) := by
  generalize hk : Frame.guardF v cap arms next body :: k = ks at h
  induction h generalizing x with
  | K_Guard _ _ _ _ _ _ _ _ _ _ _ _ hb _ _ _ _ _ =>
    cases hk
    have hi := hb.input_annotation
    have hv := HasTypeVQ.V_Sub hw hle hi.wf hi.sorted hi.declared
    cases hb
    exact hv.canonical_boolean (by
      simp [Capture.closeTy,substTyValues,Ty.bind,Ty.rawBind,Ty.core,Ty.norm])
  | K_Sub _ hsub ih => exact ih hw (hle.trans hsub) hk
  | _ => cases hk

/-! ## 値・escape・失敗・終了の状態 -/

/-- 値を返す計算は、継続が空なら終端であり、そうでなければ先頭の枠に応じて遷移する。 -/
theorem StateTyE.return_progress {P B σ Eb q k μ v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .ret v) :
    (State.run q k μ).Final ∨ ∃ l s', Step P B σ (.run q k μ) l s' := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,_,hk,_⟩ := h
  have hvt := hq.ret_view_typed hP hPB hB hs.wf hs.sorted hs.declared hv
  cases k with
  | nil => exact .inl ⟨v,hv⟩
  | cons f k =>
    right
    cases f with
    | letF n => exact ⟨_,_,.E_Return hv⟩
    | mark => exact ⟨_,_,.E_Mark hv⟩
    | update l => exact ⟨_,_,.E_Update hv⟩
    | release w =>
      obtain ⟨r,hr⟩ := hk.release_response_exists hB
      cases r with
      | none => exact ⟨_,_,.E_Release hv hr⟩
      | some r => exact ⟨_,_,.E_RelErr hv hr⟩
    | handleF cap cs => exact ⟨_,_,.E_HRet hv⟩
    | drop κ =>
      obtain ⟨_,_,_,_,hκ⟩ := hk.drop_cell
      rcases hs.cont_cell hκ with ⟨k',hc,_⟩ | hc
      · exact ⟨_,_,.E_DropRel hv hc⟩
      · exact ⟨_,_,.E_Drop hv hc⟩
    | guardF w cap arms next body =>
      obtain ⟨c,rfl⟩ := hk.guard_boolean hvt .refl
      cases c
      · exact ⟨_,_,.E_GuardF hv⟩
      · exact ⟨_,_,.E_GuardT hv⟩

/-- escape は関数の本体の中でだけ型が付き、継続の先頭の枠に応じて遷移する。 -/
theorem StateTyE.escape_progress {P B σ Eb q k μ v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .escape v) :
    ∃ l s', Step P B σ (.run q k μ) l s' := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,_,hk,_⟩ := h
  obtain ⟨r,hR,_⟩ := hq.escape_view_value hP hPB hB hs.wf hs.sorted hs.declared hv
  cases k with
  | nil =>
    obtain ⟨_,_,hRe,_⟩ := hk.nil_inv rfl
    rw [hR] at hRe; cases hRe
  | cons f k =>
    cases f with
    | letF n => exact ⟨_,_,.E_EscLet hv⟩
    | mark => exact ⟨_,_,.E_EscMark hv⟩
    | update l =>
      obtain ⟨hn,_⟩ := hk.update_inv
      rw [hR] at hn; cases hn
    | release w =>
      obtain ⟨r,hr⟩ := hk.release_response_exists hB
      cases r with
      | none => exact ⟨_,_,.E_EscRel hv hr⟩
      | some r => exact ⟨_,_,.E_EscRelErr hv hr⟩
    | handleF cap cs => exact ⟨_,_,.E_EscHandle hv⟩
    | drop κ =>
      obtain ⟨_,_,_,_,hκ⟩ := hk.drop_cell
      rcases hs.cont_cell hκ with ⟨k',hc,_⟩ | hc
      · exact ⟨_,_,.E_EscDropRel hv hc⟩
      · exact ⟨_,_,.E_EscDrop hv hc⟩
    | guardF w cap arms next body =>
      obtain ⟨hn,_⟩ := hk.guard_effect rfl
      rw [hR] at hn; cases hn

/-- 失敗の状態は、継続が空なら終端であり、そうでなければ先頭の枠を外す。 -/
theorem StateTyE.error_progress {P B σ Eb rs k μ} (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.error rs k μ)) :
    (State.error rs k μ).Final ∨ ∃ l s', Step P B σ (.error rs k μ) l s' := by
  obtain ⟨Ψ,R,a,b,e,hs,hk,_⟩ := h
  cases k with
  | nil => exact .inl trivial
  | cons f k =>
    right
    cases f with
    | letF n => exact ⟨_,_,.E_ErrPopLet⟩
    | mark => exact ⟨_,_,.E_ErrPopMark⟩
    | update l => exact ⟨_,_,.E_ErrPopUpdate⟩
    | release w =>
      obtain ⟨r,hr⟩ := hk.release_response_exists hB
      cases r with
      | none => exact ⟨_,_,.E_ErrRel hr⟩
      | some r => exact ⟨_,_,.E_ErrRelErr hr⟩
    | handleF cap cs => exact ⟨_,_,.E_ErrPopHandle⟩
    | drop κ =>
      obtain ⟨_,_,_,_,hκ⟩ := hk.drop_cell
      rcases hs.cont_cell hκ with ⟨k',hc,_⟩ | hc
      · exact ⟨_,_,.E_ErrDropRel hc⟩
      · exact ⟨_,_,.E_ErrDrop hc⟩
    | guardF w cap arms next body => exact ⟨_,_,.E_ErrPopGuard⟩

/-- 終了の状態は、継続が空なら終端であり、そうでなければ先頭の枠を外す。 -/
theorem StateTyE.exit_progress {P B σ Eb n rs k μ} (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.exit n rs k μ)) :
    (State.exit n rs k μ).Final ∨ ∃ l s', Step P B σ (.exit n rs k μ) l s' := by
  obtain ⟨Ψ,R,a,b,e,hs,hk,_⟩ := h
  cases k with
  | nil => exact .inl trivial
  | cons f k =>
    right
    cases f with
    | letF m => exact ⟨_,_,.E_ExitPopLet⟩
    | mark => exact ⟨_,_,.E_ExitPopMark⟩
    | update l => exact ⟨_,_,.E_ExitPopUpdate⟩
    | release w =>
      obtain ⟨r,hr⟩ := hk.release_response_exists hB
      cases r with
      | none => exact ⟨_,_,.E_ExitRel hr⟩
      | some r => exact ⟨_,_,.E_ExitRelErr hr⟩
    | handleF cap cs => exact ⟨_,_,.E_ExitPopHandle⟩
    | drop κ =>
      obtain ⟨_,_,_,_,hκ⟩ := hk.drop_cell
      rcases hs.cont_cell hκ with ⟨k',hc,_⟩ | hc
      · exact ⟨_,_,.E_ExitDropRel hc⟩
      · exact ⟨_,_,.E_ExitDrop hc⟩
    | guardF w cap arms next body => exact ⟨_,_,.E_ExitPopGuard⟩

/-! ## 照合の途中の状態 -/

private theorem arms_alts {P B Ψ Q C Γ Φ R obs arms a b ε L}
    (h : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b ε L) :
    ∀ arm ∈ arms, ∃ δ, AltsTy P arm.alts a δ := by
  match h with
  | .nil _ => intro arm hm; cases hm
  | .plain ha _ _ _ _ hrest =>
    intro arm hm
    rcases List.mem_cons.mp hm with rfl | hm
    · exact ⟨_,ha⟩
    · exact arms_alts hrest arm hm
  | .guarded ha _ _ _ _ _ _ hrest =>
    intro arm hm
    rcases List.mem_cons.mp hm with rfl | hm
    · exact ⟨_,ha⟩
    · exact arms_alts hrest arm hm
termination_by structural h

/-- guard のない腕の選択肢の pattern が値に合えば、その腕に最初の一致がある。 -/
private theorem unguarded_select {P a v p} :
    ∀ {arms : List Arm}, (∀ arm ∈ arms, ∃ δ, AltsTy P arm.alts a δ) →
      p ∈ unguardedPats arms → (matchVal p v).isSome →
      ∃ (j : Nat) (alts : List Alt) (body : Comp) (ws : List Val),
        arms[j]? = some (Arm.mk alts none body) ∧ firstAlt v alts = some ws
  | [], _, hp, _ => by simp [unguardedPats] at hp
  | Arm.mk alts guard body :: arms, halts, hp, hm => by
    have hrest : ∀ arm ∈ arms, ∃ δ, AltsTy P arm.alts a δ :=
      fun arm h => halts arm (List.mem_cons_of_mem _ h)
    have later : (∃ (j : Nat) (as : List Alt) (bd : Comp) (ws : List Val),
          arms[j]? = some (Arm.mk as none bd) ∧ firstAlt v as = some ws) →
        ∃ (j : Nat) (as : List Alt) (bd : Comp) (ws : List Val), (Arm.mk alts guard body :: arms)[j]? = some (Arm.mk as none bd) ∧
          firstAlt v as = some ws := by
      rintro ⟨j,as,bd,ws,hj,hf⟩
      exact ⟨j+1,as,bd,ws,by simpa using hj,hf⟩
    cases guard with
    | some g => exact later (unguarded_select hrest (by simpa [unguardedPats] using hp) hm)
    | none =>
      simp only [unguardedPats,List.mem_append,List.mem_map] at hp
      rcases hp with ⟨alt,halt,rfl⟩ | hp
      · cases hf : firstAlt v alts with
        | none =>
          obtain ⟨δ,ha⟩ := halts _ List.mem_cons_self
          have hn := MatchFacts.firstAlt_none_all ha hf alt halt
          simp [hn] at hm
        | some ws => exact ⟨0,alts,body,ws,by simp,hf⟩
      · exact later (unguarded_select hrest hp hm)

private theorem resolve_unguarded {ρ : Nat → LocalRef} {alts : List Alt} {body : Comp} :
    ∀ {arms : List Arm} {j : Nat}, arms[j]? = some (Arm.mk alts none body) →
      ∃ body', (Arm.resolveLocalsList ρ arms)[j]? = some (Arm.mk alts none body')
  | [], _, h => by simp at h
  | Arm.mk as g m :: arms, j, h => by
    cases j with
    | zero =>
      simp only [List.getElem?_cons_zero,Option.some.injEq,Arm.mk.injEq] at h
      obtain ⟨rfl,rfl,rfl⟩ := h
      exact ⟨Comp.resolveLocals (upLocalSubst (Benitoite.Release.Arm.bindersOf as) ρ) m,
        by simp [Arm.resolveLocalsList]⟩
    | succ j =>
      simp only [List.getElem?_cons_succ] at h
      obtain ⟨b',hb⟩ := resolve_unguarded (ρ := ρ) h
      cases g <;> exact ⟨b',by simpa [Arm.resolveLocalsList] using hb⟩

/-- 照合の途中の状態は、網羅性と未確認の腕の範囲から、次の腕へ進むか本体か guard へ遷移する。 -/
theorem StateTyE.match_progress {P B σ Eb v cap arms next k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.matchRun v cap arms next k μ)) :
    ∃ l s', Step P B σ (.matchRun v cap arms next k μ) l s' := by
  have hpref : MatchPrefix v arms next := by
    obtain ⟨_,_,_,_,_,_,_,_,_,_,_,_,hp,_⟩ := h; exact hp
  obtain ⟨Ψ,R,Γ,Φ,Rs,root,obs,arms0,input,result,effects,L,ρ,hs,hc,hroot,_,harms,hex,_,
    harmsEq,hv,_⟩ := h.match_inputs
  have hvt := close_value_typed hP hPB hB hs.wf hs.sorted hs.declared hc hroot
  obtain ⟨p,hp,hpm⟩ := Capture.typed_coverage hPB.variance hvt hex
  rw [←hv] at hpm
  obtain ⟨j,alts,body0,ws,hj,hf⟩ := unguarded_select (arms_alts harms) hp hpm
  obtain ⟨body1,hj'⟩ := resolve_unguarded (ρ := ρ) hj
  rw [←harmsEq] at hj'
  have hlt : next < arms.length := by
    rcases Nat.lt_or_ge next arms.length with hlt | hge
    · exact hlt
    · exfalso
      have hmem : Arm.mk alts none body1 ∈ arms.take next := by
        rw [List.take_of_length_le hge]; exact List.mem_of_getElem? hj'
      have hn := hpref _ hmem rfl
      change firstAlt v alts = none at hn
      rw [hf] at hn; cases hn
  have har : arms[next]? = some arms[next] := List.getElem?_eq_getElem hlt
  generalize arms[next] = ar at har
  obtain ⟨alts',guard',body'⟩ := ar
  cases hs' : firstAlt v alts' with
  | none => exact ⟨_,_,.E_MatchSkip har hs'⟩
  | some ws' =>
    cases guard' with
    | none => exact ⟨_,_,.E_MatchBody har hs'⟩
    | some g => exact ⟨_,_,.E_MatchGuard har hs'⟩

/-! ## 依存列の長さ -/

private theorem signatureTel_names :
    ∀ (ns : List String) (ps : List Ty) (r : Ty) (e : Eff), ns.length = ps.length →
      (signatureTel ns ps r e).names = ns
  | [], [], _, _, _ => rfl
  | n :: ns, p :: ps, r, e, h => by
    simp only [signatureTel,Tel.names,signatureTel_names ns ps r e (by simpa using h)]
  | [], _ :: _, _, _, h => by cases h
  | _ :: _, [], _, _, h => by cases h

private theorem instantiated_arity (t : Tel) (rs : List RangeExpr) (ts : List Ty) (es : List Eff) :
    (instantiatedTel (Tel.instR rs t) ts es).arity = t.arity := by
  simp only [Tel.arity,instantiatedTel,Tel.names_bind,Tel.instR_eq_bind]

private theorem arguments_length : ∀ {t : Tel} {vs : List Val} {x},
    Tel.arguments t vs = some x → vs.length = t.arity
  | .done _ _, [], _, _ => rfl
  | .param _ _ t, v :: vs, x, h => by
    simp only [Tel.arguments,Option.map_eq_some_iff] at h
    obtain ⟨y,hy,_⟩ := h
    have := arguments_length hy
    simp only [Tel.arity,Tel.names,Tel.names_bind] at this ⊢
    simp [this]
  | .done _ _, _ :: _, _, h => by simp [Tel.arguments] at h
  | .param _ _ _, [], _, h => by simp [Tel.arguments] at h

/-! ## ハンドラの探索 -/

/-- どの枠も処理しないのでなければ、最も内側の処理する枠で継続を分けられる。 -/
theorem SplitAt.of_not_noHandler {o : OpRef} : ∀ {k : Cont}, ¬ NoHandler k o →
    ∃ k1 cap h k2, SplitAt o k k1 cap h k2
  | [], hno => absurd (fun _ _ hin => by simp at hin) hno
  | f :: k, hno => by
    by_cases hf : ∃ cap h, f = .handleF cap h ∧ handles h o = true
    · obtain ⟨cap,h,rfl,hh⟩ := hf
      exact ⟨[],cap,h,k,rfl,hh,fun _ _ hin => by simp at hin⟩
    · have hno' : ¬ NoHandler k o := by
        intro hk; apply hno; intro cap h hin
        rcases List.mem_cons.mp hin with e | hin
        · cases hh : handles h o
          · rfl
          · exact absurd ⟨cap,h,e.symm,hh⟩ hf
        · exact hk cap h hin
      obtain ⟨k1,cap,h,k2,e,hh,hn⟩ := SplitAt.of_not_noHandler hno'
      refine ⟨f :: k1,cap,h,k2,by rw [e]; rfl,hh,fun cap' h' hin => ?_⟩
      rcases List.mem_cons.mp hin with e' | hin
      · cases hh' : handles h' o
        · rfl
        · exact absurd ⟨cap',h',e'.symm,hh'⟩ hf
      · exact hn cap' h' hin

/-- 操作を処理する節の一覧には、その操作の節がある。 -/
theorem findClause_of_handles {h : List Clause} {o : OpRef} (hh : handles h o = true) :
    ∃ c, findClause h o = some c := by
  unfold handles at hh
  unfold findClause
  obtain ⟨c,hc,hco⟩ := List.any_eq_true.mp hh
  cases e : h.find? (fun c => c.op == o) with
  | none => rw [List.find?_eq_none] at e; exact (e c hc hco).elim
  | some c' => exact ⟨c',rfl⟩

/-! ## 組み込みの関数の呼出し -/

private theorem store_arguments {P B Ψ b s ts es rs ws r e}
    (h : BuiltinArgs P B Ψ b s ts es rs ws r e)
    (hn : s.tparams.length = 1) (he : s.neffs = 0) (hr : s.rkinds = []) :
    ∃ a, ts = [a] ∧ es = [] ∧ rs = [] ∧ Ty.Annotation P [] [] a ∧ a.Normal := by
  have ht := h.admissible.typeCount
  rw [hn] at ht
  cases ts with
  | nil => cases ht
  | cons a ts =>
    have hts : ts = [] := List.length_eq_zero_iff.mp (by simpa using ht)
    subst ts
    have hes : es = [] := List.length_eq_zero_iff.mp (h.admissible.rowCount.trans he)
    have hrs : rs = [] := List.length_eq_zero_iff.mp (by simpa [hr] using h.ranges.1)
    exact ⟨a,rfl,hes,hrs,h.signature.types a List.mem_cons_self,(h.types a List.mem_cons_self).2⟩

private def refTel (kind : PrimKind) (a : Ty) : Tel :=
  match kind with
  | .refNew => .param "value" a (.done (.reference a) (Eff.single stateEff))
  | .refGet => .param "reference" (.reference a) (.done a (Eff.single stateEff))
  | .refSet => .param "reference" (.reference a)
      (.param "value" a (.done (.base .unit) (Eff.single stateEff)))
  | .refUpdate => .param "reference" (.reference a)
      (.param "f" (.fn ["value"] [a] a Eff.empty) (.done (.base .unit) (Eff.single stateEff)))
  | _ => .done (.base .unit) Eff.empty

private theorem store_tel {s : PrimSig} {a : Ty}
    (hk : s.kind = .refNew ∨ s.kind = .refGet ∨ s.kind = .refSet ∨ s.kind = .refUpdate)
    (hs : s.StoreShape) (hn : a.Normal) (hw : a.WF 0 0 0) :
    instantiatedTel (Tel.instR [] s.tel) [a] [] = refTel s.kind a := by
  change a.norm = a at hn
  rcases hk with hk | hk | hk | hk
  all_goals
    simp only [PrimSig.StoreShape,hk] at hs
    rcases hs with ⟨hns,_,_,hps,hr,he,_,_⟩
    simp only [instantiatedTel,Tel.bind,typeEnvAt,Nat.not_lt_zero,↓reduceIte,Nat.sub_zero,
      List.length_cons,List.length_nil,List.map_nil,Tel.instR,Tel.substRAt,Tel.mapRanges,
      PrimSig.tel,hns,hps,hr,he,Eff.single,signatureTel,Tel.rawMapRanges,Ty.rawMapRanges,
      Eff.rawMapRanges,Tel.norm,Ty.norm,Eff.norm,Tel.rawBind,Ty.rawBind,Nat.zero_lt_succ,
      List.getElem?_cons_zero,Option.getD_some,SubstEnv.up,Eff.rawBind,instAtoms_nil,
      substAtoms_nil,rowFails,List.range_zero,List.filter_nil,List.flatMap_nil,List.append_nil,refTel,hk]
    first
    | solve | simp only [shiftTypes_zero,hn,Ty.shiftV_of_wf_zero hw,mapRangeAtoms_rangeAt,
        instAtoms_nil,Nat.zero_add,Nat.lt_one_iff,upValues_id,mapRangesTys,Ty.normTys_eq_map,
        List.map_nil,Order.sortUnique_nil,rawBindTys_eq_map]
    | simp [shiftTypes_zero,Ty.shiftV_of_wf_zero hw,hn,rawBindTys,mapRangesTys,Ty.normTys,
        mapRangeAtoms_rangeAt,instAtoms_nil,Ty.rawBind,Ty.rawMapRanges,Ty.norm,Eff.empty,
        Eff.rawMapRanges,Eff.rawBind,Eff.norm,substAtoms_nil,instAtoms_nil,rowFails]


private theorem force_tel {s : PrimSig} {a : Ty}
    (hk : s.kind = .force) (hs : s.StoreShape) (hn : a.Normal) (hw : a.WF 0 0 0) :
    instantiatedTel (Tel.instR [] s.tel) [a] [] = .param "value" (.lazy a) (.done a Eff.empty) := by
  change a.norm = a at hn
  simp only [PrimSig.StoreShape,hk] at hs
  rcases hs with ⟨hns,_,_,hps,hr,he,_⟩
  simp only [instantiatedTel,Tel.bind,typeEnvAt,Nat.not_lt_zero,↓reduceIte,Nat.sub_zero,
    List.length_cons,List.length_nil,List.map_nil,Tel.instR,Tel.substRAt,Tel.mapRanges,
    PrimSig.tel,hns,hps,hr,he,Eff.empty,signatureTel,Tel.rawMapRanges,Ty.rawMapRanges,
    Eff.rawMapRanges,Tel.norm,Ty.norm,Eff.norm,Tel.rawBind,Ty.rawBind,Nat.zero_lt_succ,
    List.getElem?_cons_zero,Option.getD_some,SubstEnv.up,Eff.rawBind,instAtoms_nil,
    substAtoms_nil,rowFails,List.range_zero,List.filter_nil,List.flatMap_nil,List.append_nil]
  simp only [shiftTypes_zero,hn,Ty.shiftV_of_wf_zero hw,mapRangeAtoms_rangeAt,
    instAtoms_nil,Nat.zero_add,Nat.lt_one_iff,upValues_id,mapRangesTys,Ty.normTys_eq_map,
    List.map_nil,Order.sortUnique_nil,rawBindTys_eq_map]

/-- 参照の四つの組み込みの実引数は、具体化した署名の依存列で型が付く。 -/
private theorem reference_arguments {P B Ψ b s ts es rs ws r e}
    (hB : B.CoreAssumptions P) (hs : B.sig b = some s)
    (hk : s.kind = .refNew ∨ s.kind = .refGet ∨ s.kind = .refSet ∨ s.kind = .refUpdate)
    (h : BuiltinArgs P B Ψ b s ts es rs ws r e) :
    ∃ a, HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws (refTel s.kind a) r e := by
  have sh := hB.store_shape b s hs (by rcases hk with hk | hk | hk | hk <;> simp [hk])
  have sh' := sh
  rcases hk with hk | hk | hk | hk
  all_goals
    simp only [PrimSig.StoreShape,hk] at sh'
    obtain ⟨a,rfl,rfl,rfl,ha,hn⟩ := store_arguments h sh'.2.1 sh'.2.2.1 sh'.2.2.2.2.2.2.1
    have ht := h.arguments
    rw [store_tel (by simp [hk]) sh hn ha.wf] at ht
    exact ⟨a,ht⟩

/-- 遅延の組み込みの実引数は、遅延の型を持つ一つの値である。 -/
private theorem force_arguments {P B Ψ b s ts es rs ws r e}
    (hB : B.CoreAssumptions P) (hs : B.sig b = some s) (hk : s.kind = .force)
    (h : BuiltinArgs P B Ψ b s ts es rs ws r e) :
    ∃ a, HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws (.param "value" (.lazy a) (.done a Eff.empty)) r e := by
  have sh := hB.store_shape b s hs (by simp [hk])
  have sh' := sh
  simp only [PrimSig.StoreShape,hk] at sh'
  obtain ⟨a,rfl,rfl,rfl,ha,hn⟩ := store_arguments h sh'.2.1 sh'.2.2.1 sh'.2.2.2.2.2.2
  have ht := h.arguments
  rw [force_tel hk sh hn ha.wf] at ht
  exact ⟨a,ht⟩

private theorem rest_length {P B Ψ Q C Γ Φ ws t a e w}
    (h : HasTypeTelArgsQ P B Ψ Q C Γ Φ ws (Tel.bind (Tel.argumentsEnv w) t) a e) :
    ws.length = t.arity := by
  rw [h.length]; simp only [Tel.arity,Tel.names_bind]

/-- 引数のない列には空の実引数だけが型付く。 -/
private theorem no_arguments {P B Ψ b s ts es rs ws r e}
    (hp : s.params = []) (h : BuiltinArgs P B Ψ b s ts es rs ws r e) : ws = [] := by
  have hl := h.arguments.length
  rw [instantiated_arity] at hl
  simp only [PrimSig.tel,hp] at hl
  cases hn : s.names <;> simp_all [signatureTel,Tel.arity,Tel.names]

/-- 組み込みの関数の呼出しは、種類ごとの規則で遷移する。IO・終了は処理する枠があればその節へ移り、PathBases は同じ継続の発行状態へ進む。 -/
theorem StateTyE.primitive_progress {P B σ Eb q k μ b ts es rs ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es (List.map RangeIx.fixed rs)) ws) :
    ∃ l s', Step P B σ (.run q k μ) l s' := by
  obtain ⟨_,_,_,_,sg,_,_,_,_,hsig,hra,hpa,_⟩ := h.primitive_contract_inputs hP hPB hB hv
  have hparts := h
  obtain ⟨Ψ,R,a,c,e,e1,hs,hq,_,_,_,hcl,_⟩ := hparts
  obtain ⟨r,ef,hargs,_,_⟩ := hq.primitive_view_inputs hP hPB hB hs.wf hs.sorted hs.declared hcl hv hsig
  have handled : (sg.kind = .io ∨ sg.kind = .exit) →
      ¬ NoHandler k (.prim b) → ∃ l s', Step P B σ (.run q k μ) l s' := by
    intro hk hno
    obtain ⟨k1,cap,cs,k2,hsplit⟩ := SplitAt.of_not_noHandler hno
    obtain ⟨c',hc⟩ := findClause_of_handles hsplit.2.1
    obtain ⟨κ,hκ,_⟩ := hs.fresh
    exact ⟨_,_,.E_OpPrim hv hsig hk hsplit hc hκ⟩
  cases hkind : sg.kind with
  | pure =>
    obtain ⟨_,_,_,hst⟩ := step_pure_selected (σ := σ) (oracle := B.selectOracle)
      (externalOracle := B.selectExternal) (rel := B.selectRelease) (fresh := Store.selectFresh)
      (k := k) (μ := μ) hB hv hsig hkind hargs
    exact ⟨_,_,hst⟩
  | io =>
    by_cases hno : NoHandler k (.prim b)
    · obtain ⟨_,_,_,hst⟩ := h.selected_primitive_step (externalOracle := B.selectExternal)
        (rel := B.selectRelease) (fresh := Store.selectFresh) hP hPB hB hv hsig (.inr (.inl hkind)) hno
      exact ⟨_,_,hst⟩
    · exact handled (.inl hkind) hno
  | exit =>
    by_cases hno : NoHandler k (.prim b)
    · obtain ⟨_,_,_,hst⟩ := h.selected_primitive_step (externalOracle := B.selectExternal)
        (rel := B.selectRelease) (fresh := Store.selectFresh) hP hPB hB hv hsig (.inr (.inr hkind)) hno
      exact ⟨_,_,hst⟩
    · exact handled (.inr hkind) hno
  | pathBases =>
    have hw : ws = [] := no_arguments (hB.pathBases_shape b sg hsig hkind).arguments hargs
    obtain ⟨rfl,rfl,rfl⟩ := hB.pathBases_empty_arguments hsig hkind hpa hra
    subst hw
    exact ⟨_,_,(h.path_bases_apply_all hP hPB hB hv hsig hkind).1⟩
  | refNew =>
    obtain ⟨x,ht⟩ := reference_arguments hB hsig (.inl hkind) hargs
    simp only [hkind,refTel] at ht
    cases ht with
    | param _ _ hrest =>
      have hl := rest_length hrest
      simp only [Tel.arity,Tel.names,List.length_nil] at hl
      obtain rfl := List.length_eq_zero_iff.mp hl
      obtain ⟨κ,hκ,_⟩ := hs.fresh
      exact ⟨_,_,.E_RefNew hv hsig hkind hκ⟩
  | refGet =>
    obtain ⟨x,ht⟩ := reference_arguments hB hsig (.inr (.inl hkind)) hargs
    simp only [hkind,refTel] at ht
    cases ht with
    | param _ hw hrest =>
      have hl := rest_length hrest
      simp only [Tel.arity,Tel.names,List.length_nil] at hl
      obtain rfl := List.length_eq_zero_iff.mp hl
      obtain ⟨l,y,rfl,hΨ,_⟩ := hw.canonical_ref rfl
      obtain ⟨v,hc,_⟩ := hs.ref_cell hΨ
      exact ⟨_,_,.E_RefGet hv hsig hkind hc⟩
  | refSet =>
    obtain ⟨x,ht⟩ := reference_arguments hB hsig (.inr (.inr (.inl hkind))) hargs
    simp only [hkind,refTel] at ht
    cases ht with
    | param _ hw hrest =>
      have hl := rest_length hrest
      simp only [Tel.arity,Tel.names,List.length_cons,List.length_nil] at hl
      obtain ⟨v,rfl⟩ : ∃ v, _ = [v] := List.length_eq_one_iff.mp hl
      obtain ⟨l,y,rfl,_,_⟩ := hw.canonical_ref rfl
      exact ⟨_,_,.E_RefSet hv hsig hkind⟩
  | refUpdate =>
    obtain ⟨x,ht⟩ := reference_arguments hB hsig (.inr (.inr (.inr hkind))) hargs
    simp only [hkind,refTel] at ht
    cases ht with
    | param _ hw hrest =>
      have hl := rest_length hrest
      simp only [Tel.arity,Tel.names,List.length_cons,List.length_nil] at hl
      obtain ⟨f,rfl⟩ : ∃ f, _ = [f] := List.length_eq_one_iff.mp hl
      obtain ⟨l,y,rfl,_,_⟩ := hw.canonical_ref rfl
      exact ⟨_,_,.E_RefUpdate hv hsig hkind⟩
  | force =>
    obtain ⟨x,ht⟩ := force_arguments hB hsig hkind hargs
    cases ht with
    | param _ hw hrest =>
      have hl := rest_length hrest
      simp only [Tel.arity,Tel.names,List.length_nil] at hl
      obtain rfl := List.length_eq_zero_iff.mp hl
      obtain ⟨l,y,rfl,hΨ,_⟩ := hw.canonical_lazy rfl
      rcases hs.lazy_cell hΨ with ⟨m,hc,_⟩ | ⟨v,hc,_⟩
      · exact ⟨_,_,.E_Force hv hsig hkind hc⟩
      · exact ⟨_,_,.E_ForceDone hv hsig hkind hc⟩

/-! ## 利用者の操作と失敗 -/

private inductive EffectAtom (l : EffName) (ix : RangeIx) : Tel → Prop where
  | done {e : Eff} : e.mem (.name l ix) → EffectAtom l ix (.done a e)
  | param : EffectAtom l ix t → EffectAtom l ix (.param n a t)
private theorem EffectAtom.norm {l ix t} (h : EffectAtom l ix t) : EffectAtom l ix t.norm := by
  induction h with
  | done hm => exact .done (by simpa using hm)
  | param h ih => exact .param ih
private theorem EffectAtom.bind {l ix t} (h : EffectAtom l ix t) (θ : SubstEnv) :
    EffectAtom l (ix.inst θ.ranges) (Tel.bind θ t) := by
  unfold Tel.bind
  apply EffectAtom.norm
  induction h generalizing θ with
  | done hm => exact .done ((Eff.mem_rawBind θ _ _).mpr (.inl ⟨_,hm,rfl,trivial⟩))
  | param h ih => exact .param (ih θ.up)
private theorem EffectAtom.signature {ns ps a l ix} {e : Eff} (h : e.mem (.name l ix)) :
    EffectAtom l ix (signatureTel ns ps a e) := by
  induction ns generalizing ps with
  | nil => exact .done h
  | cons n ns ih => cases ps with
    | nil => exact .done h
    | cons p ps => exact .param ih
private theorem EffectAtom.arguments {P B Ψ Q C Γ Φ ws t a e l r}
    (h : HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t a e)
    (hm : EffectAtom l (.fixed r) t) : e.mem (.name l (.fixed r)) := by
  induction ws generalizing t with
  | nil => cases h; cases hm with | done hm => exact hm
  | cons v vs ih => cases h with
    | param ha hv hs => cases hm with
      | param hm => exact ih hs (hm.bind (Tel.argumentsEnv v))
/-- 利用者の操作の呼出しの効果は、操作の効果名の原子を継続の効果に含む。 -/
private theorem operation_effect {P B σ Eb q k μ o ts ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.op o ts) ws) :
    ∃ Ψ R a b e od jx, ContTy P B σ Ψ R e k a b Eb none ∧ P.ops o = some od ∧
      e.mem (.name od.eff jx) := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,hsub,hk,_⟩ := h
  have closed := hq.app_view_typed hP hPB hB hs.wf hs.sorted hs.declared hv
  have reg : CaptureContextRegular P [] [] := by
    constructor <;> (intro i a hi; cases hi)
  obtain ⟨t,r,ef,hf,args,_,cov⟩ := closed.app_tel rfl hs.wf hs.sorted hs.declared reg
  obtain ⟨od,u,hd,_,_,inst,core,relation⟩ := hf.inv_op rfl
  cases Option.some.inj core
  obtain ⟨result,effects,original,_,cover⟩ := relation.apply
    (by intro i a hi; cases hi) inst.result args
  have hatom : EffectAtom od.eff (.fixed .top) od.tel := by
    unfold OpDecl.tel
    exact EffectAtom.signature (by simp [Eff.mem,Eff.test,Eff.atoms])
  have hm := EffectAtom.arguments original (hatom.bind (typeEnvAt 0 ts []))
  obtain ⟨x,hx,hcx⟩ := (cov.trans cover).1 _ hm
  obtain ⟨jx,rfl⟩ := hcx.name_right
  exact ⟨Ψ,R,a,b,e,od,jx,hk,hd,hsub.1 _ hx⟩

/-- 継続の末尾の効果が組み込みの効果だけなら、利用者の操作には処理する枠があり、その節へ移る。 -/
theorem StateTyE.operation_progress {P B σ Eb q k μ o ts ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hdecl : P.EffectsOk B) (hB : B.CoreAssumptions P)
    (hEb : BuiltinOnly P B Eb) (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .app (.op o ts) ws) :
    ∃ l s', Step P B σ (.run q k μ) l s' := by
  by_cases hno : NoHandler k (.user o)
  · exfalso
    obtain ⟨Ψ,R,a,b,e,od,jx,hk,hd,hm⟩ := operation_effect hP hPB hB h hv
    obtain ⟨os,hos,hmem⟩ := hdecl.2.1 o od hd
    have hn : ∀ cap cs ix, Frame.handleF cap cs ∈ k → ¬ (handled P B cs).mem (.name od.eff ix) := by
      intro cap cs ix hf hh
      have hc := hno cap cs hf
      have hall : (os.map OpRef.user).all (handles cs) = false := by
        rw [Bool.eq_false_iff]; intro hall
        have := List.all_eq_true.mp hall (.user o) (List.mem_map.mpr ⟨o,hmem,rfl⟩)
        rw [hc] at this; cases this
      simp only [handled,effOps,hos,issuesSelected,Eff.mem,Eff.test,Eff.atoms] at hh
      revert hall hh
      cases os.map OpRef.user <;> simp
    obtain ⟨kx,hk',_⟩ := hk.name_end_ix hm hn
    obtain ⟨l,r,he,hnone,_⟩ := hEb.2 _ hk'
    cases he
    rw [hos] at hnone; cases hnone
  · obtain ⟨k1,cap,cs,k2,hsplit⟩ := SplitAt.of_not_noHandler hno
    obtain ⟨c,hc⟩ := findClause_of_handles hsplit.2.1
    obtain ⟨Ψ,R,a,b,e,e1,hs,_⟩ := h
    obtain ⟨κ,hκ,_⟩ := hs.fresh
    exact ⟨_,_,.E_Op hv hsplit hc hκ⟩

private theorem clauses_no_fail {P B Ψ Q C Γ Φ R eb cs t ec L}
    (h : HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t ec L) : handles cs .fail = false := by
  match h with
  | .nil => rfl
  | .cons hsig _ _ _ _ _ hcs =>
    have hn := hsig.ne_fail
    have ih := clauses_no_fail hcs
    simp only [handles,List.any_cons,Clause.op,Bool.or_eq_false_iff] at ih ⊢
    exact ⟨Bool.eq_false_iff.mpr (fun hb => hn (beq_iff_eq.mp hb)),ih⟩
termination_by structural h

/-- どの枠も Fail を処理しない継続では、継続の効果の Fail は末尾の効果に残る。 -/
theorem ContTy.fail_end {P B σ Ψ R ε k a b Eb Re t}
    (h : ContTy P B σ Ψ R ε k a b Eb Re) (hf : ε.memFail t) (hn : NoHandler k .fail) :
    ∃ t', Eb.memFail t' := by
  induction h generalizing t with
  | K_Empty he _ => exact ⟨t,he.2 t hf⟩
  | K_Let _ _ _ _ _ ih | K_Mark _ _ ih | K_Update _ _ _ ih | K_Release _ _ _ _ _ ih | K_Drop _ _ _ ih =>
    exact ih hf (fun cap cs hm => hn cap cs (List.mem_cons_of_mem _ hm))
  | K_Sub _ _ ih => exact ih hf hn
  | K_Handle _ hc hb _ _ _ _ _ _ _ _ _ _ ih =>
    rcases (Eff.memFail_union_iff _ _ _).mp (hb.2 t hf) with hm | hm
    · exact ih (hc.2 t hm) (fun cap cs hm => hn cap cs (List.mem_cons_of_mem _ hm))
    · obtain ⟨x,hx,_⟩ := hm
      simp [handled,Eff.fails] at hx
  | K_Handle_Fail _ _ _ _ hcs _ _ _ _ _ _ _ _ _ =>
    exfalso
    have hh := hn _ _ List.mem_cons_self
    cases hcs
    simp [handles,Clause.op] at hh
  | K_Guard =>
    obtain ⟨x,hx,_⟩ := hf
    simp [Eff.empty,Eff.fails] at hx

/-- Fail を処理する枠は、Fail の一節だけを持つ。 -/
theorem ContTy.fail_clauses {P B σ Ψ R ε k a b Eb Re cap cs k1 k2}
    (h : ContTy P B σ Ψ R ε k a b Eb Re) (he : k = k1 ++ .handleF cap cs :: k2)
    (hh : handles cs .fail = true) : ∃ E body, cs = [.fail E body] := by
  induction h generalizing k1 with
  | K_Empty _ _ => cases k1 <;> simp at he
  | K_Sub _ _ ih => exact ih he
  | K_Handle _ _ _ _ hcs _ _ _ _ _ _ _ _ ih =>
    cases k1 with
    | nil =>
      simp only [List.nil_append,List.cons.injEq,Frame.handleF.injEq] at he
      obtain ⟨⟨rfl,rfl⟩,rfl⟩ := he
      rw [clauses_no_fail hcs] at hh; cases hh
    | cons f k1 =>
      simp only [List.cons_append,List.cons.injEq] at he
      exact ih he.2
  | K_Handle_Fail _ _ _ _ hcs _ _ _ _ _ _ _ _ ih =>
    cases k1 with
    | nil =>
      simp only [List.nil_append,List.cons.injEq,Frame.handleF.injEq] at he
      obtain ⟨⟨rfl,rfl⟩,rfl⟩ := he
      cases hcs
      exact ⟨_,_,rfl⟩
    | cons f k1 =>
      simp only [List.cons_append,List.cons.injEq] at he
      exact ih he.2
  | K_Let _ _ _ _ _ ih =>
    cases k1 with
    | nil => simp at he
    | cons f k1 =>
      simp only [List.cons_append,List.cons.injEq] at he
      exact ih he.2
  | K_Mark _ _ ih =>
    cases k1 with
    | nil => simp at he
    | cons f k1 =>
      simp only [List.cons_append,List.cons.injEq] at he
      exact ih he.2
  | K_Update _ _ _ ih =>
    cases k1 with
    | nil => simp at he
    | cons f k1 =>
      simp only [List.cons_append,List.cons.injEq] at he
      exact ih he.2
  | K_Release _ _ _ _ _ ih =>
    cases k1 with
    | nil => simp at he
    | cons f k1 =>
      simp only [List.cons_append,List.cons.injEq] at he
      exact ih he.2
  | K_Drop _ _ _ ih =>
    cases k1 with
    | nil => simp at he
    | cons f k1 =>
      simp only [List.cons_append,List.cons.injEq] at he
      exact ih he.2
  | K_Guard _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ ih =>
    cases k1 with
    | nil => simp at he
    | cons f k1 =>
      simp only [List.cons_append,List.cons.injEq] at he
      exact ih he.2

/-- 継続の末尾の効果が Fail を持たないので、raise には Fail を処理する枠があり、その節へ移る。 -/
theorem StateTyE.raise_progress {P B σ Eb q k μ t e0 ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hEb : BuiltinOnly P B Eb) (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .app (.raise t e0) ws) :
    ∃ l s', Step P B σ (.run q k μ) l s' := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,hsub,hk,_⟩ := h
  have closed := hq.app_view_typed hP hPB hB hs.wf hs.sorted hs.declared hv
  have reg : CaptureContextRegular P [] [] := by
    constructor <;> (intro i a hi; cases hi)
  obtain ⟨t',r,ef,hf,args,_,_⟩ := closed.app_tel rfl hs.wf hs.sorted hs.declared reg
  obtain ⟨u,h0,_,_,_,core,relation⟩ := hf.inv_raise rfl
  cases Option.some.inj core
  obtain ⟨result,effects,original,_,_⟩ := relation.apply (by intro i a hi; cases hi) h0.toTel args
  have hlen := original.length
  rw [Tel.arity_toTel ⟨rfl,by simp⟩] at hlen
  obtain ⟨w,rfl⟩ : ∃ w, ws = [w] := List.length_eq_one_iff.mp hlen
  obtain ⟨_,_,hcov⟩ := closed.failure_call
  have hfail : e.memFail e0 := hsub.2 _ (hcov.2 _ ⟨e0.norm,by simp [Eff.singleFail,Eff.fails],Ty.norm_idem e0⟩)
  by_cases hno : NoHandler k .fail
  · obtain ⟨_,x,hx,_⟩ := hk.fail_end hfail hno
    rw [hEb.1] at hx; cases hx
  · obtain ⟨k1,cap,cs,k2,hsplit⟩ := SplitAt.of_not_noHandler hno
    obtain ⟨E,body,rfl⟩ := hk.fail_clauses hsplit.1 hsplit.2.1
    obtain ⟨κ,hκ,_⟩ := hs.fresh
    exact ⟨_,_,.E_OpFail hv hsplit hκ⟩

/-! ## 関数の適用・メソッド・再開 -/

/-- 関数の適用は、関数の値の形ごとの規則で遷移する。 -/
theorem StateTyE.app_progress {P B σ Eb q k μ f ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hdecl : P.EffectsOk B) (hB : B.CoreAssumptions P)
    (hEb : BuiltinOnly P B Eb) (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app f ws) :
    ∃ l s', Step P B σ (.run q k μ) l s' := by
  obtain ⟨Ψ,R,a,e,t,r,ef,_,_,hf,_,_,_,_⟩ := h.app_inputs hP hPB hB hv
  rcases hf.canonical_function (t := t) rfl with
    ⟨g,ts,es,rs,rfl⟩ | ⟨b,ts,es,rs,rfl⟩ | ⟨o,ts,rfl⟩ | ⟨ns,ps,body,rfl⟩ | ⟨t',body,rfl⟩ |
      ⟨rt,body,rfl⟩ | ⟨t',e',rfl⟩ | ⟨g,ts,rfl⟩
  · obtain ⟨_,_,_,_,d,_,_,_,_,hd,hnames,had,_,hargs,_,_⟩ := h.fnRef_contract_inputs_ranges hP hPB hB hv
    have hws : ws.length = d.params.length := by
      rw [hargs.length]
      simp only [Tel.arity,instantiatedTel,Tel.names_bind,Def.instTel_names,Def.tel]
      rw [signatureTel_names _ _ _ _ hnames.1]
      exact hnames.1
    have hts : ts.length = d.ntys := by
      simpa [TypeCtx.constraints,Def.ntys] using had.types.1
    exact ⟨_,_,(h.fun_step_ranges hP hPB hB hv hd hws hts had.rowCount).1⟩
  · exact h.primitive_progress hP hPB hB hv
  · exact h.operation_progress hP hPB hdecl hB hEb hv
  · exact ⟨_,_,(h.lambda_inputs hP hPB hB hv rfl).1⟩
  · exact ⟨_,_,(h.lambda_inputs hP hPB hB hv rfl).1⟩
  · exact ⟨_,_,(h.lambda_inputs hP hPB hB hv rfl).1⟩
  · exact h.raise_progress hP hPB hB hEb hv
  · exact ⟨_,_,.E_ExternalApply hv⟩

/-- 型が付いた上位の辞書の取り出しは、実装の上位の辞書を一段取り出す。 -/
private theorem super_step_exists {P B Ψ Q C Φ} (hPB : P.WellTyped B) :
    ∀ (w : Val) (s : ClassName) {T}, HasTypeVQ P B Ψ Q C [] Φ (.super w s) T →
      ∃ w', (Val.super w s).superStep P = some w'
  | w, s, T, h => by
    obtain ⟨cl,a,cd,hw,hcl,hs,_,_⟩ := h.inv_super rfl
    rcases hw.canonical_dict (cl := cl) (a := a.norm) (by simp [Ty.norm,Ty.core]) with ⟨i,us,vs,rfl⟩ | ⟨w',s',rfl⟩
    · obtain ⟨id,hi,_,_,_,_,_,_,_,hcore⟩ := hw.inv_dict rfl
      simp only [Ty.norm,Ty.core,Ty.dict.injEq] at hcore
      obtain ⟨cd',hcd',_,_,_,_,_,hsupers⟩ := hPB.impls i id hi
      rw [←hcore.1,hcl] at hcd'
      cases hcd'
      obtain ⟨u,hu,_⟩ := hsupers s hs
      exact ⟨(u.substTy us []).instantiate vs,by simp [Val.superStep,hi,hu]⟩
    · obtain ⟨w'',hw''⟩ := super_step_exists hPB w' s' hw
      exact ⟨_,by
        change ((Val.super w' s').superStep P).map (fun v' => Val.super v' s) = _
        rw [hw'']; rfl⟩

/-- メソッドの呼出しは、実装の辞書なら本体へ、上位の辞書なら一段の取り出しへ遷移する。 -/
theorem StateTyE.method_progress {P B σ Eb q k μ v m ss es ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .meth v m ss es ws) :
    ∃ l s', Step P B σ (.run q k μ) l s' := by
  have hparts := h
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,_⟩ := hparts
  have hm := hq.method_view_typed hP hPB hB hs.wf hs.sorted hs.declared hv
  obtain ⟨cl,τ,cd,ms,as,a',ε,hvd,hcl,hms,hnames,hsat,_,hrows,harg,hws,_,_,_⟩ := hm.inv_meth rfl
  rcases hvd.canonical_dict (cl := cl) (a := τ.norm) (by simp [Ty.norm,Ty.core]) with ⟨i,us,vs,rfl⟩ | ⟨w,s,rfl⟩
  · obtain ⟨id,hi,husat,_,_,_,_,hvs,_,hcore⟩ := hvd.inv_dict rfl
    simp only [Ty.norm,Ty.core,Ty.dict.injEq] at hcore
    obtain ⟨cd',hcd',_,_,_,_,hmeths,_⟩ := hPB.impls i id hi
    rw [←hcore.1,hcl] at hcd'
    cases hcd'
    obtain ⟨body,hbody,_⟩ := hmeths m ms hms
    have hwl : ws.length = ms.params.length := by
      rw [arguments_length harg]
      simp only [Tel.arity,instantiatedTel,Tel.names_bind,MethSig.tel]
      rw [signatureTel_names _ _ _ _ hnames.1]
      exact hnames.1
    have hvl : vs.length = id.dictTys.length := by simpa using hvs.length
    have hss : ss.length = ms.tparams.length := by simpa [TypeCtx.constraints] using hsat.1
    exact ⟨_,_,(h.method_step hP hPB hB hv hi hbody (hcore.1 ▸ hcl) hms hwl hvl husat.1 hss
      hrows.1).1⟩
  · obtain ⟨w',hw'⟩ := super_step_exists hPB w s hvd
    exact ⟨_,_,(h.super_step hP hPB hB hv hw').1⟩

private theorem resume_form {P B Ψ Q C Γ Φ R code T E L f v}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code T E L) (hc : code = .resume f v) :
    (∃ i, f = .var i) ∨ (∃ l, f = .loc l) := by
  match h with
  | .C_Resume .. | .C_ResumeNorm .. => cases hc; exact Or.inl ⟨_,rfl⟩
  | .C_ResumeL .. | .C_ResumeLNorm .. => cases hc; exact Or.inr ⟨_,rfl⟩
  | .C_Sub h .. | .C_Eff h .. | .C_Normal h => exact resume_form h hc
  | .C_Return .. | .C_BuilderLet .. | .C_BuilderOp .. | .C_Let .. | .C_App .. |
      .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. |
      .C_Use .. | .C_Handle .. | .C_Handle_Fail .. | .C_Meth .. | .C_External .. |
      .C_IssuePathBases .. | .C_CheckAt .. => cases hc
termination_by structural h

private def Comp.isResume : Comp → Bool
  | .resume .. => true
  | _ => false

/-- 再開の第一の値は継続の場所であり、保存した継続か使用済みの印に応じて遷移する。 -/
theorem StateTyE.resume_progress {P B σ Eb q k μ w v}
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .resume w v) :
    ∃ l s', Step P B σ (.run q k μ) l s' := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,hrest⟩ := h
  have hloc : ∃ l x t' e' r', w = .loc l ∧ Ψ l = some (.cont x t' e' r') := by
    obtain ⟨cap,Γ,Φ,Rs,code0,as,es,L,ρ,hqe,hcap,hbody,hL,hR,ha,he,hd⟩ := hq.open_zero
    subst hqe
    have htag : code0.isResume = true := by
      have hh := congrArg Comp.isResume hv
      cases code0 <;> first | exact hh | (cases hh) | skip
    cases code0 <;> try cases htag
    case resume kv v0 =>
    change Comp.resume (closeVal cap (kv.resolveLocals ρ)) (closeVal cap (v0.resolveLocals ρ)) = _ at hv
    obtain ⟨hkv,_⟩ := Comp.resume.inj hv
    rcases resume_form hbody rfl with ⟨i,rfl⟩ | ⟨l,rfl⟩
    · rcases hbody.inv_resumeVar rfl with ⟨_,_,_,hi,_⟩ | ⟨_,_,_,hi,_⟩
      all_goals
        have hh := hcap.substOk _ _ hi
        cases hh with
        | ordinary ho _ => exact False.elim (ho _ _ _ rfl)
        | hidden _ hn => exact False.elim (hn _ _ _ rfl)
        | contVar _ _ hx => obtain ⟨_,_,_,hx,_⟩ := hx; cases hx
        | contLoc _ _ _ he hl _ =>
          refine ⟨_,_,_,_,_,?_,hl⟩
          rw [←hkv]
          exact he
    · rcases hbody.inv_resumeL rfl with ⟨_,_,_,hl,_⟩ | ⟨_,_,_,_,hl,_⟩
      · exact ⟨l,_,_,_,_,hkv.symm,hl⟩
      · exact ⟨l,_,_,_,_,hkv.symm,hl⟩
  obtain ⟨l,x,t',e',r',rfl,hΨ⟩ := hloc
  rcases hs.cont_cell hΨ with ⟨k',hc,_⟩ | hc
  · exact ⟨_,_,.E_Resume hv hc⟩
  · exact ⟨_,_,.E_ResumeErr hv hc⟩

/-! ## builder の操作 -/

private theorem join_total : ∀ {vs : List Val}, (∀ v ∈ vs, ∃ t, v = .const (.string t)) →
    ∃ t, builderJoin vs = some t
  | [], _ => ⟨"",rfl⟩
  | v :: vs, h => by
    obtain ⟨t,rfl⟩ := h v List.mem_cons_self
    obtain ⟨u,hu⟩ := join_total (fun w hw => h w (List.mem_cons_of_mem _ hw))
    exact ⟨t ++ u,by simp [builderJoin,hu]⟩

private theorem string_value {P B Ψ Q C Φ v T} (h : HasTypeVQ P B Ψ Q C [] Φ v T)
    (ht : T.norm.core = .base .string) : ∃ t, v = .const (.string t) := by
  obtain ⟨c,rfl,_,hc⟩ := h.canonical_scalar ht
  cases c <;> simp [Const.type,Ty.norm,Ty.core] at hc
  exact ⟨_,rfl⟩

private theorem byte_value {P B Ψ Q C Φ v T} (h : HasTypeVQ P B Ψ Q C [] Φ v T)
    (ht : T.norm.core = .base .byte) : ∃ b, v = .const (.byte b) := by
  obtain ⟨c,rfl,_,hc⟩ := h.canonical_scalar ht
  cases c <;> simp [Const.type,Ty.norm,Ty.core] at hc
  exact ⟨_,rfl⟩

/-- 型付きの実引数と内容からは、builder の操作の応答が必ず一つ得られる。上限を超える場合は誤りの応答である。 -/
private theorem builder_apply_total {P B Ψ kind c op args}
    (hok : BuilderCellOk P B Ψ kind c)
    (hargs : HasTypeVsQ P B Ψ Qempty [] [] [] args (op.parameters kind)) :
    ∃ reply, builderApply op c args = some reply := by
  obtain ⟨hsize,hpay⟩ := hok
  have hlim : c.size ≤ c.limit := by
    cases kind <;> cases c <;> first | exact hsize | exact (hpay : False).elim
  cases op with
  | copy => cases hargs; exact ⟨_,rfl⟩
  | length => cases hargs; exact ⟨_,dite_eq_left hlim⟩
  | append =>
    cases kind <;> cases c <;> try exact (hpay : False).elim
    all_goals
      obtain _ | ⟨hv,rest⟩ := hargs
      cases rest
    · obtain ⟨t,rfl⟩ := string_value hv (by simp [BuilderKind.item,Ty.norm,Ty.core])
      exact ⟨_,rfl⟩
    · exact ⟨_,rfl⟩
    · obtain ⟨t,rfl⟩ := byte_value hv (by simp [BuilderKind.item,Ty.norm,Ty.core])
      exact ⟨_,rfl⟩
  | appendAll =>
    cases kind <;> cases c <;> try exact (hpay : False).elim
    all_goals
      obtain _ | ⟨hv,rest⟩ := hargs
      cases rest
    · obtain ⟨vs,b',rfl,heach,hle⟩ := hv.canonical_list (a := .base .string) rfl
      have hann : Ty.Annotation P [] [] (.base .string) := ⟨trivial,trivial,trivial⟩
      obtain ⟨t,ht⟩ := join_total (vs := vs) (fun w hw =>
        string_value (.V_Sub (heach.member hw) hle hann.wf hann.sorted hann.declared)
          (by simp [Ty.norm,Ty.core]))
      exact ⟨_,by simp only [builderApply,ht,Option.map_some]; exact rfl⟩
    · obtain ⟨ws,b',rfl,_,_⟩ := hv.canonical_list rfl
      exact ⟨_,rfl⟩
    · obtain ⟨bs,rfl⟩ := hv.canonical_bytes (by simp [BuilderKind.contents,Ty.norm,Ty.core])
      exact ⟨_,rfl⟩

/-- builder の操作は、生きている builder のセルへの操作の応答で遷移する。 -/
theorem StateTyE.builder_progress {P B σ Eb q k μ kind op r args}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .builderOp kind op r args) :
    ∃ l s', Step P B σ (.run q k μ) l s' := by
  have hparts := h
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,hrest⟩ := hparts
  obtain ⟨hkind,hlocal,hargs,_⟩ := builder_operation_inputs
    (builder_view_operation hP hPB hB hs.wf hs.sorted hs.declared hq hv) rfl
  cases r with
  | bound i =>
    exfalso
    have : ∀ {ref b}, LocalRef.HasKind Ψ [] ref b → ∀ j, ref ≠ .bound j := by
      intro ref b hk
      induction hk with
      | bound hi => intro j _; simp at hi
      | loc _ => intro j hj; cases hj
      | normal _ ih => exact ih
    exact this hlocal i rfl
  | loc l =>
    obtain ⟨source,hsource,hkn⟩ := builder_local_inv hlocal rfl
    obtain ⟨c,hc,hok,_⟩ := hs.builder_cell hsource
    obtain ⟨reply,hr⟩ := builder_apply_total (builder_cell_convert hok hkind hkn) hargs
    cases reply with
    | value c' v => exact ⟨_,_,.E_BuilderOp hv hc hr⟩
    | error r => exact ⟨_,_,.E_BuilderErr hv hc hr⟩

/-! ## run の状態と全体 -/

private theorem resolve_issue {ρ : Nat → LocalRef} {m : Comp} {b : PrimName}
    (h : Comp.resolveLocals ρ m = .issuePathBases b) : m = .issuePathBases b := by
  cases m with
  | issuePathBases b0 => simpa [Comp.resolveLocals] using h
  | checkAt k o sh bs p v ix => cases bs <;> simp [Comp.resolveLocals] at h
  | _ => simp [Comp.resolveLocals] at h

/-- run の状態は、計算の形ごとに終端か遷移を持つ。 -/
theorem StateTyE.run_progress {P B σ Eb q k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hdecl : P.EffectsOk B) (hB : B.CoreAssumptions P)
    (hσ : σ.Valid) (hEb : BuiltinOnly P B Eb) (h : StateTyE P B σ Eb (.run q k μ)) :
    (State.run q k μ).Final ∨ ∃ l s', Step P B σ (.run q k μ) l s' := by
  have hparts := h
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,hrest⟩ := hparts
  obtain ⟨cap,code⟩ := q
  cases code with
  | builderLet kind body =>
    obtain ⟨l,hl,_⟩ := hs.fresh
    exact .inr ⟨_,_,.E_BuilderNew rfl hl⟩
  | builderOp kind op r args => exact .inr (h.builder_progress hP hPB hB rfl)
  | ret v => exact h.return_progress hP hPB hB rfl
  | letIn m n => exact .inr ⟨_,_,.E_Let rfl⟩
  | app f ws => exact .inr (h.app_progress hP hPB hdecl hB hEb rfl)
  | ite v m n =>
    obtain ⟨c,hc,_⟩ := h.if_inputs hP hPB hB rfl
    have hv : (Closure.mk cap (.ite v m n)).view = .ite (.const (.boolean c)) m n := by
      change Comp.ite (closeVal cap v) m n = _
      simp only [Closure.capture] at hc
      rw [hc]
    cases c
    · exact .inr ⟨_,_,.E_IfF hv⟩
    · exact .inr ⟨_,_,.E_IfT hv⟩
  | «match» v arms => exact .inr ⟨_,_,.E_Match rfl⟩
  | lazyC m =>
    obtain ⟨l,hl,_⟩ := hs.fresh
    exact .inr ⟨_,_,.E_Lazy rfl hl⟩
  | escape v => exact .inr (h.escape_progress hP hPB hB rfl)
  | use v m => exact .inr ⟨_,_,.E_Use rfl⟩
  | handle m cs => exact .inr ⟨_,_,.E_Handle rfl⟩
  | resume w v => exact .inr (h.resume_progress rfl)
  | externalCall f ts vs =>
    obtain ⟨_,_,_,_,_,hst,_⟩ := StateTyE.external_response_step hP hPB hB h rfl
    exact .inr ⟨_,_,hst⟩
  | issuePathBases b =>
    obtain ⟨cap',Γ,Φ,Rs,code0,as,es,L,ρ,hqe,hcap,hbody,hL,hR,ha,he,hd⟩ := hq.open_zero
    obtain ⟨_,hcode⟩ := Closure.mk.inj hqe
    obtain ⟨sg,hsig,hk,hop,_⟩ := hbody.inv_issuePathBases (resolve_issue hcode.symm)
    exact .inr ⟨_,_,.E_IssuePathBases rfl hsig hk hop hσ⟩
  | checkAt kind name shape bases pattern input index =>
    obtain ⟨next,hst,_⟩ := StateTyE.at_step hP hPB hB hσ h rfl
    exact .inr ⟨_,_,hst⟩
  | meth v m ss es ws => exact .inr (h.method_progress hP hPB hB rfl)

/-- 進行。型が付いた状態は終端であるか、遷移を持つ。 -/
theorem StateTyE.progress {P B σ Eb s}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hdecl : P.EffectsOk B) (hB : B.CoreAssumptions P)
    (hσ : σ.Valid) (hEb : BuiltinOnly P B Eb) (h : StateTyE P B σ Eb s) :
    s.Final ∨ ∃ l s', Step P B σ s l s' := by
  cases s with
  | run q k μ => exact h.run_progress hP hPB hdecl hB hσ hEb
  | matchRun v cap arms next k μ => exact .inr (h.match_progress hP hPB hB)
  | error rs k μ => exact h.error_progress hB
  | exit n rs k μ => exact h.exit_progress hB

end
end Benitoite.Release.Refinement
