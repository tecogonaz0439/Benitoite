import Benitoite.Release.Refinement.SurfaceTargetStepExamples

/-!
# 節の添字の許容を外した誤った規則の反例

`handle File.readTextIn["/data/**"](checked(/data/a.txt)) with { … }` の三つの節（`File.Read` の三つの操作）は、
捕捉した引数を `File.readTextIn["/etc/**"]` へ渡す。本番の規則 `ClauseIxOk` は、保護本体の効果
`{File.Read["/data/**"]}` のもとで `File.readTextIn` の節に Top と規則の値 `/data/**` だけを許し、`/etc/**` を許さない
（`etc_not_clauseIxOk`）。添字の許容を問わない誤った規則（`WrongHandleTyped`。本番の `C_Handle` と
`HasTypeClausesQ.cons` の前提のうち、節の操作の型 `ClauseSig` だけを任意の添字の `opSigAt` に替えた）は、この handle を
初期の効果 `{File.Read["/etc/**"]}` で型付ける（`wrong_rule_admits`）。しかし実行は `/data/a.txt` を観測する読取りの事象へ
到達し、その観測は初期の効果に許されない（`wrong_rule_unsound`）。到達先の対象健全性から、本番の型付けはこの handle を
その効果で型付けない（`handleEtc_rejected`。設計書 01-12「確かめる性質」、07-04「証明する性質」）。
-/
namespace Benitoite.Release.Refinement.Surface.TargetStepExamples
noncomputable section
open StandardModel TargetObservedExamples Scope.Domain

/-- `/etc/**`。 -/
def etcRange : RangeExpr := .absolute (.path (.tree ["etc"]))
/-- `/etc/x`。 -/
def etcTarget : Target := .path ["etc", "x"]
/-- 初期の効果 `{File.Read["/etc/**"]}`。 -/
def etcBound : Eff := .mk (fun a => decide (a = .name "File.Read" (.fixed etcRange))) []

/-- `File.readTextIn["/etc/**"](x)`。 -/
def etcRead (x : Val) : Comp := .app (.prim "File.readTextIn" [] [] [.fixed etcRange]) [x]

/-- `File.Read` の三つの操作の節。`File.readText` の節は検査済みの `/etc/x` を、ほかの二つは捕捉した引数を読む。 -/
def etcClauses : List Clause :=
  [.mk (.prim "File.readText") 1 0 (etcRead (.checked etcTarget)),
   .mk (.prim "File.readTextIn") 1 0 (etcRead (.var 1)),
   .mk (.prim "File.readBytesIn") 1 0 (etcRead (.var 1))]

def handleEtc : Comp := .handle readComp etcClauses
def handleEtcClosure : Closure := Closure.pure handleEtc

/-- 誤った節の規則（反例のためのモデル）による節の列の型付け。本番の `HasTypeClausesQ.cons` の前提のうち、節の操作の型
`ClauseSig`（節の添字 S の許容 `ClauseIxOk` と具体化 `opSigAt`）だけを、許容を問わない `opSigAt P B S o = some sg` に
替えた（開始の閉包の空の文脈に限る）。 -/
inductive WrongClausesTyped (P : Refinement.Program) (B : Builtins) : StoreTy → Eff → List Clause → Ty → Eff → Prop where
  | nil {Ψ eb t ε} : WrongClausesTyped P B Ψ eb [] t ε
  | cons {Ψ eb o n k body cs t ε sg} (S : RangeExpr) : opSigAt P B S o = some sg →
      (∀ (b : PrimName) (s : PrimSig), o = .prim b → B.sig b = some s → s.tel.RowsIn (· < s.neffs)) →
      NamesWF sg.names sg.params → n = sg.params.length → k = sg.tparams.length → sg.WF →
      HasTypeCQ P B (hideBuilders Ψ) Qempty (sg.tparams ++ []) (sg.context [] t ε)
        (liftMany (sg.params.length + 1) []) none body
        ((shiftTypes sg.tparams.length 0 t).shiftV (sg.params.length + 1) 0)
        ((shiftRowsTypes sg.tparams.length 0 ε).shiftV (sg.params.length + 1) 0) [] →
      WrongClausesTyped P B Ψ eb cs t ε → WrongClausesTyped P B Ψ eb (.mk o n k body :: cs) t ε

/-- 誤った規則による handle の型付け。ほかの前提（保護本体の型付け、`εm ⊆ ε ∪ handled(H)`、節の本体を出力の上限 ε で
型付けること）は本番の `C_Handle` と同じである。 -/
def WrongHandleTyped (P : Refinement.Program) (B : Builtins) (m : Comp) (h : List Clause) (t : Ty) (ε : Eff) : Prop :=
  ∃ εm, HasTypeCQ P B StoreTy.empty Qempty [] [] [] none m t εm [] ∧
    Eff.Sub εm (Eff.union ε (handled P B h)) ∧ WrongClausesTyped P B StoreTy.empty εm h t ε

/-- 本番の節の型付けは誤った規則の節の型付けでもある（誤った規則は許容の条件を外しただけである）。 -/
theorem wrong_of_clauses {P B Ψ eb h t ε} (hc : HasTypeClausesQ P B Ψ Qempty [] [] [] none eb h t ε []) :
    WrongClausesTyped P B Ψ eb h t ε := by
  induction h with
  | nil => exact .nil
  | cons c cs ih =>
    cases hc with
    | cons hsig hn hl hk hw hb hr =>
      obtain ⟨S, -, hs, hrows⟩ := hsig
      exact .cons S hs hrows hn hl hk hw (by simpa using hb) (ih hr)

/-- 本番の規則は、保護本体の効果 `{File.Read["/data/**"]}` のもとで `File.readTextIn` の節に添字 `/etc/**` を許さない。 -/
theorem etc_not_clauseIxOk (p : String) : ¬ ClauseIxOk (table p) readBound (.prim "File.readTextIn") etcRange := by
  rintro (h | ⟨b, s, l, hb, hs, hl, -, hr, -⟩)
  · simp [etcRange] at h
  · cases hb
    rw [sig_read] at hs
    cases hs
    simp [ScopeSignatures.readTextIn, ScopeSignatures.ioIn] at hl
    subst hl
    simp [readBound, Eff.mem, Eff.test, Eff.atoms, dataRange, etcRange] at hr


/-! ## 誤った規則による型付け -/

private theorem etc_instantiated :
    instantiatedTel (Tel.instR [etcRange] ScopeSignatures.readTextIn.tel) [] [] =
      .param "path" (.opaque "Scope.PathIn" (.fixed etcRange)) (.done readResult etcBound) := by
  have atoms : mapRangeAtoms (rangeAt 0 [etcRange])
      (fun a => decide (a = .name "File.Read" (.rvar 0))) =
      (fun a => decide (a = .name "File.Read" (.fixed etcRange))) := by
    funext a
    simp [mapRangeAtoms,mapAtomRanges,mapIx,rangeAt,eq_comm]
  simp [ScopeSignatures.readTextIn,ScopeSignatures.ioIn,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,
    Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,atoms,
    Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
    Eff.norm,typeEnvAt,substAtoms_nil,instAtoms_nil,rowFails,readResult,etcBound,
    RangeIx.inst,SubstEnv.up]

/-- どの文脈でも、`PathIn["/etc/**"]` の値を `/etc/**` の範囲で読む呼出しは効果 `{File.Read["/etc/**"]}` で型付く。 -/
theorem etcRead_typed (p : String) {Ψ : StoreTy} {Γ : Ctx} {Φ : List Pred} {x : Val}
    (hx : HasTypeVQ (core p) (table p) Ψ Qempty [] Γ Φ x (.opaque "Scope.PathIn" (.fixed etcRange))) :
    HasTypeCQ (core p) (table p) Ψ Qempty [] Γ Φ none (etcRead x) readResult etcBound [] := by
  have hann : ∀ Γ : Ctx, Ty.Annotation (core p) [] Γ readResult := result_annotation p
  refine .C_DependentApp (.V_Prim (rs := [etcRange]) rfl ?_ (by simp [ScopeSignatures.readTextIn,ScopeSignatures.ioIn,NamesWF])
    ?_ ?_) ?_
  · refine ⟨rfl,?_,?_,Or.inr ⟨by simp, rfl⟩⟩
    · intro i r k hr hk
      cases i <;> simp at hr hk
      cases hr; cases hk
      decide
    · intro r hr; simp at hr; subst r
      exact ⟨by decide,by decide⟩
  · constructor
    · rfl
    · rfl
    · simp
    · rfl
    · simp
    · simp [ScopeSignatures.readTextIn,ScopeSignatures.ioIn,Eff.RowsIn,Ty.RowsInList]
    · intro i h; simp [Qsig,ScopeSignatures.readTextIn,ScopeSignatures.ioIn,QTys,QTy,QEff,Benitoite.Release.Qempty] at h
    · intro i h; simp [Qsig,ScopeSignatures.readTextIn,ScopeSignatures.ioIn,QTys,QTy,QEff,Benitoite.Release.Qempty] at h
    · simp [ScopeSignatures.readTextIn,ScopeSignatures.ioIn,PrimSig.tel,signatureTel,Tel.RowsIn,Ty.RowsIn,
        Ty.RowsInList,Eff.RowsIn]
  · constructor
    · simp [ScopeSignatures.readTextIn,ScopeSignatures.ioIn,PrimSig.tel,signatureTel,Tel.instR,Tel.substRAt,
        Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,
        Ty.WF,Ty.WFList,Tel.WF,Tel.norm,Ty.norm,Eff.norm,Eff.WF,Eff.Canonical,
        RangeIx.inst,RangeIx.WF]
    · simp [TypeAnnotations]
    · exact ⟨rfl,by intro i a k h; cases i <;> cases h⟩
    · simp [RowAnnotations]
    · simp
    · rw [etc_instantiated]
      exact ⟨by trivial,by trivial,⟨trivial,(hann _).declared,trivial⟩⟩
  · rw [etc_instantiated]
    refine .param ⟨trivial,trivial,trivial⟩ hx ?_
    simp only [Tel.bind_done]
    have hb : readResult.bind (Tel.argumentsEnv x) = readResult := by
      simp [readResult,Ty.bind,Ty.rawBind,rawBindTys,Ty.norm,Ty.normTys,RangeIx.inst]
    have he : Eff.bind (Tel.argumentsEnv x) etcBound = etcBound := by
      simp [etcBound,Eff.bind,Eff.rawBind,Tel.argumentsEnv,valEnv,Eff.norm,substAtoms_nil,instAtoms_nil,rowFails]
    rw [hb,he]
    exact .done ⟨⟨by trivial,by trivial⟩,⟨by trivial,by trivial⟩,⟨(hann _).declared,trivial⟩⟩


/-- `File.readText` の節の操作の型（範囲を持たない）。 -/
def sgText : OpSig := ⟨[], ["path"], [.base .string], readResult, "File.Read"⟩
/-- `File.readTextIn`・`File.readBytesIn` の節を添字 `/etc/**` で具体化した操作の型。捕捉した引数は `PathIn["/etc/**"]`
を持つ。 -/
def sgEtcText : OpSig := ⟨[], ["path"], [.opaque "Scope.PathIn" (.fixed etcRange)], readResult, "File.Read"⟩
def sgEtcBytes : OpSig :=
  ⟨[], ["path"], [.opaque "Scope.PathIn" (.fixed etcRange)],
    .data "Result" [.bytes, .opaque "IOError" .top], "File.Read"⟩

theorem opSig_text (p : String) : opSigAt (core p) (table p) (.absolute .top) (.prim "File.readText") = some sgText := by
  simp [opSigAt, sgText, readResult]
  rfl
theorem opSig_etcText (p : String) : opSigAt (core p) (table p) etcRange (.prim "File.readTextIn") = some sgEtcText := by
  simp [opSigAt, sig_read, sgEtcText, readResult, ScopeSignatures.readTextIn, ScopeSignatures.ioIn, Ty.instTarget]
  rfl
theorem opSig_etcBytes (p : String) :
    opSigAt (core p) (table p) etcRange (.prim "File.readBytesIn") = some sgEtcBytes := by
  simp [opSigAt, sgEtcBytes]
  rfl


private theorem rows_read (p : String) (o : OpRef) (ho : o = .prim "File.readText" ∨ o = .prim "File.readTextIn" ∨
    o = .prim "File.readBytesIn") :
    ∀ (b : PrimName) (s : PrimSig), o = .prim b → (table p).sig b = some s → s.tel.RowsIn (· < s.neffs) := by
  intro b s hb hs
  rcases ho with rfl | rfl | rfl <;> cases hb <;> cases hs <;>
    simp [ScopeSignatures.readTextIn, ScopeSignatures.readBytesIn, ScopeSignatures.ioIn, ModelTargets.readTextSig,
      ScopeSignatures.unscopedIO, PrimSig.tel, signatureTel, Tel.RowsIn, Ty.RowsIn, Ty.RowsInList, Eff.RowsIn, Eff.single]

/-- 誤った規則は、添字 `/etc/**` の節で handle を初期の効果 `{File.Read["/etc/**"]}` で型付ける。 -/
theorem wrong_rule_admits (p : String) : WrongHandleTyped (core p) (table p) readComp etcClauses readResult etcBound := by
  refine ⟨readBound, readComp_typed p, ⟨?_, ?_⟩, ?_⟩
  · intro a ha
    simp [readBound, Eff.mem, Eff.test, Eff.atoms] at ha
    subst ha
    have he : (core p).effects "File.Read" = none := rfl
    have hb : (table p).effects "File.Read" = some ["File.readText", "File.readTextIn", "File.readBytesIn"] := rfl
    have h1 : (table p).sig "File.readText" = some ModelTargets.readTextSig := rfl
    have h3 : (table p).sig "File.readBytesIn" = some ScopeSignatures.readBytesIn := rfl
    simp [Eff.union, Eff.mem, Eff.test, Eff.atoms, Eff.norm, handled, effOps, handles, etcClauses, he, hb,
      issuesSelected, Builtins.issuesIn, Clause.op, h1, h3, sig_read, ModelTargets.readTextSig,
      ScopeSignatures.unscopedIO, ScopeSignatures.readTextIn, ScopeSignatures.readBytesIn, ScopeSignatures.ioIn]
  · intro t ht; simp [readBound, Eff.memFail, Eff.fails] at ht
  · refine .cons (.absolute .top) (opSig_text p) (rows_read p _ (Or.inl rfl)) (by simp [sgText, NamesWF]) rfl rfl
      (by simp [sgText, OpSig.WF, BinderTypes.LocalWF, readResult, Ty.WF, Ty.WFList, RangeIx.WF]) ?_ ?_
    · have hx : HasTypeVQ (core p) (table p) (hideBuilders StoreTy.empty) Qempty [] (sgText.context [] readResult etcBound)
          (liftMany (sgText.params.length + 1) []) (.checked etcTarget) (.opaque "Scope.PathIn" (.fixed etcRange)) :=
        HasTypeVQ.checked_opaque rfl rfl (by decide)
      have := etcRead_typed p hx
      simpa [sgText, readResult, etcBound, shiftTypes, shiftRowsTypes, Ty.shiftV, Eff.shiftV] using this
    · refine .cons etcRange (opSig_etcText p) (rows_read p _ (Or.inr (Or.inl rfl))) (by simp [sgEtcText, NamesWF]) rfl rfl
        (by simp [sgEtcText, OpSig.WF, BinderTypes.LocalWF, readResult, Ty.WF, Ty.WFList, RangeIx.WF]) ?_ ?_
      · have hx : HasTypeVQ (core p) (table p) (hideBuilders StoreTy.empty) Qempty []
            (sgEtcText.context [] readResult etcBound) (liftMany (sgEtcText.params.length + 1) []) (.var 1)
            (.opaque "Scope.PathIn" (.fixed etcRange)) :=
          .V_Var (by simp [sgEtcText, OpSig.context, Ctx.extendMany, Ctx.extend, Ctx.shiftE, Ctx.shiftEAt, Ty.shiftV])
            (by simp [Ordinary])
        have := etcRead_typed p hx
        simpa [sgEtcText, readResult, etcBound, shiftTypes, shiftRowsTypes, Ty.shiftV, Eff.shiftV] using this
      · refine .cons etcRange (opSig_etcBytes p) (rows_read p _ (Or.inr (Or.inr rfl))) (by simp [sgEtcBytes, NamesWF])
          rfl rfl (by simp [sgEtcBytes, OpSig.WF, BinderTypes.LocalWF, Ty.WF, Ty.WFList, RangeIx.WF]) ?_ .nil
        have hx : HasTypeVQ (core p) (table p) (hideBuilders StoreTy.empty) Qempty []
            (sgEtcBytes.context [] readResult etcBound) (liftMany (sgEtcBytes.params.length + 1) []) (.var 1)
            (.opaque "Scope.PathIn" (.fixed etcRange)) :=
          .V_Var (by simp [sgEtcBytes, OpSig.context, Ctx.extendMany, Ctx.extend, Ctx.shiftE, Ctx.shiftEAt, Ty.shiftV])
            (by simp [Ordinary])
        have := etcRead_typed p hx
        simpa [sgEtcBytes, readResult, etcBound, shiftTypes, shiftRowsTypes, Ty.shiftV, Eff.shiftV] using this


/-! ## 実行と観測 -/

/-- E-OpPrim の後のストア（継続の場所 0 に捕捉した継続）。 -/
def etcStore : Store := Store.empty.set 0 (.cont ([] ++ [.handleF Capture.empty etcClauses]))

/-- 節の本体の IO の状態。捕捉した引数 `checked(/data/a.txt)` が `/etc/**` の読取りへ渡る。 -/
def etcState : State :=
  .run (Closure.mk (Capture.empty.extendMany ([.checked dataTarget] ++ [.loc 0])) ((etcRead (.var 1)).substTy [] []))
    [.drop 0] etcStore

/-- 開始の閉包から、E-Handle と E-OpPrim で節の本体の IO の状態へ進む（遷移は型付けによらない）。 -/
theorem reach_etc (p : String) : Steps (core p) (table p) σ0 (.run handleEtcClosure [] Store.empty) [] etcState :=
  .cons (.E_Handle rfl)
    (.cons (.E_OpPrim (rs := [dataRange]) (k1 := []) (k2 := []) (c := .mk (.prim "File.readTextIn") 1 0 (etcRead (.var 1)))
      rfl rfl (Or.inl rfl) ⟨rfl, by decide, by simp [NoHandler]⟩ rfl rfl) .nil)

/-- 節の本体の IO の事象。観測は捕捉した引数の対象 `/data/a.txt` である。 -/
theorem etc_step (p : String) :
    Step (core p) (table p) σ0 etcState
      (some (.io "File.readTextIn" [.checked dataTarget] (.err "IO") [dataTarget])) (.error ["IO"] [.drop 0] etcStore) :=
  .E_IOErr (rs := [etcRange]) rfl rfl (Or.inl rfl) (by simp [NoHandler])
    (Or.inl ⟨.readText, by decide, rfl, ⟨.readText, rfl, rfl, rfl, .err "IO", dataTarget, rfl, rfl, rfl,
      by intro h; cases h⟩⟩)

/-- 初期の効果 `{File.Read["/etc/**"]}` は `/data/a.txt` を許さない。 -/
theorem etcBound_not_allows_data (κ : EffName → Option Kind) : ¬ Eff.Allows σ0 κ etcBound "File.Read" dataTarget := by
  rintro ⟨k, r, -, hm, ht⟩
  simp [etcBound, Eff.mem, Eff.test, Eff.atoms] at hm
  subst hm
  revert ht
  simp [etcRange, dataTarget, RangeExpr.Mem, RangeExpr.resolve, Range.Mem, PathPattern.Matches]

/-- 誤った規則のもとでは到達先の対象健全性が破れる。誤った規則は handle を `{File.Read["/etc/**"]}` で型付け、
開始の閉包から到達した読取りの事象は `/data/a.txt` を観測し、その観測は初期の効果に許されない。 -/
theorem wrong_rule_unsound (p : String) :
    WrongHandleTyped (core p) (table p) readComp etcClauses readResult etcBound ∧
    Steps (core p) (table p) σ0 (.run handleEtcClosure [] Store.empty) [] etcState ∧
    Step (core p) (table p) σ0 etcState
      (some (.io "File.readTextIn" [.checked dataTarget] (.err "IO") [dataTarget])) (.error ["IO"] [.drop 0] etcStore) ∧
    ¬ Eff.Allows σ0 (table p).effKind etcBound "File.Read" dataTarget :=
  ⟨wrong_rule_admits p, reach_etc p, etc_step p, etcBound_not_allows_data _⟩

/-- 開始の条件。σ は全ての起点と secrets を束縛する。 -/
theorem handleEtc_start (p : String) : StartCondition (core p) (table p) σ0 handleEtcClosure := by
  refine ⟨by simp [handleEtcClosure, handleEtc, readComp, etcClauses, etcRead, Closure.pure, Closure.Adequate,
      Comp.Adequate, adequateClauses, Capture.Adequate, adequateCaptureSlots, Capture.empty, Val.Adequate, adequateVals],
    (by simp [handleEtcClosure, handleEtc, readComp, etcClauses, etcRead, Closure.pure, Closure.ClosedAt,
      Comp.ClosedAt, Clause.ClosedList, Val.ClosedAt, Capture.Closed, captureSlotsClosed, Capture.empty,
      Val.ClosedList, Capture.values]; decide),
    ⟨⟨by simp [PathEnv.Valid, TargetReachExamples.environment, Scope.Domain.PathWordWF], fun r _ => ?_⟩⟩⟩
  cases r with
  | base b => cases b <;> exact ⟨[], rfl⟩
  | secrets => rfl

/-- 本番の規則は、誤った規則が認めた handle の型付け（効果 `{File.Read["/etc/**"]}`）を認めない（到達先の対象健全性
から）。 -/
theorem handleEtc_rejected (p : String) (a : Ty) :
    ¬ ClosureTy (core p) (table p) StoreTy.empty [] none handleEtcClosure a etcBound := by
  intro hq
  obtain ⟨hf, hp, he, hc, ht⟩ := program_facts p
  obtain ⟨e, l, hsig, hop, hall⟩ := reachable_target_sound _ _ _ hf hp he hc ht _ _ _ hq (handleEtc_start p)
    _ _ _ _ _ _ _ (reach_etc p) (etc_step p)
  rw [sig_read] at hsig
  cases hsig
  simp [ScopeSignatures.readTextIn, ScopeSignatures.ioIn] at hop
  subst hop
  exact etcBound_not_allows_data _ (hall dataTarget (List.mem_singleton_self _))


/-! ## 別の対象を読む節 -/

/-- `/logs/**`。 -/
def logsRange : RangeExpr := .absolute (.path (.tree ["logs"]))
/-- `/logs/l.txt`。 -/
def logsTarget : Target := .path ["logs", "l.txt"]
/-- 初期の効果 `{File.Read["/logs/**"]}`。 -/
def logsBound : Eff := .mk (fun a => decide (a = .name "File.Read" (.fixed logsRange))) []

/-- `File.readTextIn["/logs/**"](checked(/logs/l.txt))`。 -/
def logsRead : Comp := .app (.prim "File.readTextIn" [] [] [.fixed logsRange]) [.checked logsTarget]

/-- `File.Read` の三つの操作の節。どれも捕捉した引数を使わず、`/logs/l.txt` を読む。 -/
def logsClauses : List Clause :=
  [.mk (.prim "File.readText") 1 0 logsRead, .mk (.prim "File.readTextIn") 1 0 logsRead,
   .mk (.prim "File.readBytesIn") 1 0 logsRead]

def handleLogs : Comp := .handle readComp logsClauses
def handleLogsClosure : Closure := Closure.pure handleLogs

private theorem logs_instantiated :
    instantiatedTel (Tel.instR [logsRange] ScopeSignatures.readTextIn.tel) [] [] =
      .param "path" (.opaque "Scope.PathIn" (.fixed logsRange)) (.done readResult logsBound) := by
  have atoms : mapRangeAtoms (rangeAt 0 [logsRange])
      (fun a => decide (a = .name "File.Read" (.rvar 0))) =
      (fun a => decide (a = .name "File.Read" (.fixed logsRange))) := by
    funext a
    simp [mapRangeAtoms,mapAtomRanges,mapIx,rangeAt,eq_comm]
  simp [ScopeSignatures.readTextIn,ScopeSignatures.ioIn,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,
    Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,atoms,
    Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
    Eff.norm,typeEnvAt,substAtoms_nil,instAtoms_nil,rowFails,readResult,logsBound,
    RangeIx.inst,SubstEnv.up]

/-- どの文脈でも、`/logs/l.txt` を読む呼出しは効果 `{File.Read["/logs/**"]}` で型付く。 -/
theorem logsRead_typed (p : String) {Ψ : StoreTy} {Γ : Ctx} {Φ : List Pred} :
    HasTypeCQ (core p) (table p) Ψ Qempty [] Γ Φ none logsRead readResult logsBound [] := by
  have hann : ∀ Γ : Ctx, Ty.Annotation (core p) [] Γ readResult := result_annotation p
  refine .C_DependentApp (.V_Prim (rs := [logsRange]) rfl ?_ (by simp [ScopeSignatures.readTextIn,ScopeSignatures.ioIn,NamesWF])
    ?_ ?_) ?_
  · refine ⟨rfl,?_,?_,Or.inr ⟨by simp, rfl⟩⟩
    · intro i r k hr hk
      cases i <;> simp at hr hk
      cases hr; cases hk
      decide
    · intro r hr; simp at hr; subst r
      exact ⟨by decide,by decide⟩
  · constructor
    · rfl
    · rfl
    · simp
    · rfl
    · simp
    · simp [ScopeSignatures.readTextIn,ScopeSignatures.ioIn,Eff.RowsIn,Ty.RowsInList]
    · intro i h; simp [Qsig,ScopeSignatures.readTextIn,ScopeSignatures.ioIn,QTys,QTy,QEff,Benitoite.Release.Qempty] at h
    · intro i h; simp [Qsig,ScopeSignatures.readTextIn,ScopeSignatures.ioIn,QTys,QTy,QEff,Benitoite.Release.Qempty] at h
    · simp [ScopeSignatures.readTextIn,ScopeSignatures.ioIn,PrimSig.tel,signatureTel,Tel.RowsIn,Ty.RowsIn,
        Ty.RowsInList,Eff.RowsIn]
  · constructor
    · simp [ScopeSignatures.readTextIn,ScopeSignatures.ioIn,PrimSig.tel,signatureTel,Tel.instR,Tel.substRAt,
        Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,
        Ty.WF,Ty.WFList,Tel.WF,Tel.norm,Ty.norm,Eff.norm,Eff.WF,Eff.Canonical,
        RangeIx.inst,RangeIx.WF]
    · simp [TypeAnnotations]
    · exact ⟨rfl,by intro i a k h; cases i <;> cases h⟩
    · simp [RowAnnotations]
    · simp
    · rw [logs_instantiated]
      exact ⟨by trivial,by trivial,⟨trivial,(hann _).declared,trivial⟩⟩
  · rw [logs_instantiated]
    refine .param ⟨trivial,trivial,trivial⟩ (HasTypeVQ.checked_opaque rfl rfl (by decide)) ?_
    simp only [Tel.bind_done]
    have hb : readResult.bind (Tel.argumentsEnv (.checked logsTarget)) = readResult := by
      simp [readResult,Ty.bind,Ty.rawBind,rawBindTys,Ty.norm,Ty.normTys,RangeIx.inst]
    have he : Eff.bind (Tel.argumentsEnv (.checked logsTarget)) logsBound = logsBound := by
      simp [logsBound,Eff.bind,Eff.rawBind,Tel.argumentsEnv,valEnv,Eff.norm,substAtoms_nil,instAtoms_nil,rowFails]
    rw [hb,he]
    exact .done ⟨⟨by trivial,by trivial⟩,⟨by trivial,by trivial⟩,⟨(hann _).declared,trivial⟩⟩

/-- 添字 Top で具体化した `File.readTextIn`・`File.readBytesIn` の操作の型。 -/
def sgTopText : OpSig := ⟨[], ["path"], [.opaque "Scope.PathIn" (.fixed (.absolute .top))], readResult, "File.Read"⟩
def sgTopBytes : OpSig :=
  ⟨[], ["path"], [.opaque "Scope.PathIn" (.fixed (.absolute .top))],
    .data "Result" [.bytes, .opaque "IOError" .top], "File.Read"⟩

theorem opSig_topText (p : String) :
    opSigAt (core p) (table p) (.absolute .top) (.prim "File.readTextIn") = some sgTopText := by
  simp [opSigAt, sig_read, sgTopText, readResult, ScopeSignatures.readTextIn, ScopeSignatures.ioIn, Ty.instTarget]
  rfl
theorem opSig_topBytes (p : String) :
    opSigAt (core p) (table p) (.absolute .top) (.prim "File.readBytesIn") = some sgTopBytes := by
  simp [opSigAt, sgTopBytes]
  rfl

/-- 本番の規則は、三つの節を添字 Top で型付け、handle を初期の効果 `{File.Read["/logs/**"]}` で型付ける。 -/
theorem handleLogs_typed (p : String) :
    HasTypeCQ (core p) (table p) StoreTy.empty Qempty [] [] [] none handleLogs readResult logsBound [] := by
  refine .C_Handle (readComp_typed p) ⟨?_, ?_⟩ ?_
  · intro a ha
    simp [readBound, Eff.mem, Eff.test, Eff.atoms] at ha
    subst ha
    have he : (core p).effects "File.Read" = none := rfl
    have hb : (table p).effects "File.Read" = some ["File.readText", "File.readTextIn", "File.readBytesIn"] := rfl
    have h1 : (table p).sig "File.readText" = some ModelTargets.readTextSig := rfl
    have h3 : (table p).sig "File.readBytesIn" = some ScopeSignatures.readBytesIn := rfl
    simp [Eff.union, Eff.mem, Eff.test, Eff.atoms, Eff.norm, handled, effOps, handles, logsClauses, he, hb,
      issuesSelected, Builtins.issuesIn, Clause.op, h1, h3, sig_read, ModelTargets.readTextSig,
      ScopeSignatures.unscopedIO, ScopeSignatures.readTextIn, ScopeSignatures.readBytesIn, ScopeSignatures.ioIn]
  · intro t ht; simp [readBound, Eff.memFail, Eff.fails] at ht
  · refine .cons (ClauseSig.of_opSig (opSig_text p) (rows_read p _ (Or.inl rfl))) (by simp [sgText, NamesWF]) rfl rfl
      (by simp [sgText, OpSig.WF, BinderTypes.LocalWF, readResult, Ty.WF, Ty.WFList, RangeIx.WF]) ?_ ?_
    · simpa [sgText, readResult, logsBound, shiftTypes, shiftRowsTypes, Ty.shiftV, Eff.shiftV] using
        (logsRead_typed p (Ψ := hideBuilders StoreTy.empty) (Γ := sgText.context [] readResult logsBound)
          (Φ := liftMany (sgText.params.length + 1) []))
    · refine .cons (ClauseSig.of_opSig (opSig_topText p) (rows_read p _ (Or.inr (Or.inl rfl))))
        (by simp [sgTopText, NamesWF]) rfl rfl
        (by simp [sgTopText, OpSig.WF, BinderTypes.LocalWF, readResult, Ty.WF, Ty.WFList, RangeIx.WF]) ?_ ?_
      · simpa [sgTopText, readResult, logsBound, shiftTypes, shiftRowsTypes, Ty.shiftV, Eff.shiftV] using
          (logsRead_typed p (Ψ := hideBuilders StoreTy.empty) (Γ := sgTopText.context [] readResult logsBound)
            (Φ := liftMany (sgTopText.params.length + 1) []))
      · refine .cons (ClauseSig.of_opSig (opSig_topBytes p) (rows_read p _ (Or.inr (Or.inr rfl))))
          (by simp [sgTopBytes, NamesWF]) rfl rfl
          (by simp [sgTopBytes, OpSig.WF, BinderTypes.LocalWF, Ty.WF, Ty.WFList, RangeIx.WF]) ?_ .nil
        simpa [sgTopBytes, readResult, logsBound, shiftTypes, shiftRowsTypes, Ty.shiftV, Eff.shiftV] using
          (logsRead_typed p (Ψ := hideBuilders StoreTy.empty) (Γ := sgTopBytes.context [] readResult logsBound)
            (Φ := liftMany (sgTopBytes.params.length + 1) []))


theorem handleLogsClosure_typed (p : String) :
    ClosureTy (core p) (table p) StoreTy.empty [] none handleLogsClosure readResult logsBound := by
  refine ClosureTy.pure (handleLogs_typed p) ⟨⟨(result_annotation p []).wf, ?_⟩, ⟨(result_annotation p []).sorted, ?_⟩,
    ⟨(result_annotation p []).declared, ?_⟩⟩ (by intro r h; cases h) rfl (by intro r h; cases h)
  · simp [logsBound,Eff.WF,Ty.WFList,Eff.Canonical,Eff.norm]
  · simp [logsBound,sortedEff,sortedTys]
  · simp [logsBound,declaredEff,declaredTys]

theorem handleLogs_start (p : String) : StartCondition (core p) (table p) σ0 handleLogsClosure := by
  refine ⟨by simp [handleLogsClosure, handleLogs, readComp, logsClauses, logsRead, Closure.pure, Closure.Adequate,
      Comp.Adequate, adequateClauses, Capture.Adequate, adequateCaptureSlots, Capture.empty, Val.Adequate, adequateVals],
    (by simp [handleLogsClosure, handleLogs, readComp, logsClauses, logsRead, Closure.pure, Closure.ClosedAt,
      Comp.ClosedAt, Clause.ClosedList, Val.ClosedAt, Capture.Closed, captureSlotsClosed, Capture.empty,
      Val.ClosedList, Capture.values]; decide),
    ⟨⟨by simp [PathEnv.Valid, TargetReachExamples.environment, Scope.Domain.PathWordWF], fun r _ => ?_⟩⟩⟩
  cases r with
  | base b => cases b <;> exact ⟨[], rfl⟩
  | secrets => rfl

/-- 保護本体の対象 `/data/a.txt` を読む呼出しを節が捕捉し、節は `/logs/l.txt` を読む。開始の閉包から到達したどの読取りの
事象も、保護本体の対象を観測しない（到達先の対象健全性）。 -/
theorem handleLogs_never_observes_data (p : String) {evs : List Event} {s s' : State} {ws : List Val} {o : Outcome}
    {obs : List Target}
    (hsteps : Steps (core p) (table p) σ0 (.run handleLogsClosure [] Store.empty) evs s)
    (hst : Step (core p) (table p) σ0 s (some (.io "File.readTextIn" ws o obs)) s') : dataTarget ∉ obs := by
  intro hd
  obtain ⟨hf, hp, he, hc, ht⟩ := program_facts p
  obtain ⟨e, l, hsig, hop, hall⟩ := reachable_target_sound _ _ _ hf hp he hc ht _ _ _
    (handleLogsClosure_typed p) (handleLogs_start p) _ _ _ _ _ _ _ hsteps hst
  rw [sig_read] at hsig
  cases hsig
  simp [ScopeSignatures.readTextIn, ScopeSignatures.ioIn] at hop
  subst hop
  obtain ⟨k, r, -, hm, hmem⟩ := hall dataTarget hd
  simp [logsBound, Eff.mem, Eff.test, Eff.atoms] at hm
  subst hm
  revert hmem
  simp [logsRange, dataTarget, RangeExpr.Mem, RangeExpr.resolve, Range.Mem, PathPattern.Matches]

/-- 開始の閉包から E-Handle と E-OpPrim で節の本体へ進み、節の読取りの事象の観測 `/logs/l.txt` は初期の効果が許す
（前提が空疎でないこと）。 -/
theorem handleLogs_reach_allowed (p : String) :
    Steps (core p) (table p) σ0 (.run handleLogsClosure [] Store.empty) []
      (.run (Closure.mk (Capture.empty.extendMany ([.checked dataTarget] ++ [.loc 0])) (logsRead.substTy [] []))
        [.drop 0] (Store.empty.set 0 (.cont ([] ++ [.handleF Capture.empty logsClauses])))) ∧
    Step (core p) (table p) σ0
      (.run (Closure.mk (Capture.empty.extendMany ([.checked dataTarget] ++ [.loc 0])) (logsRead.substTy [] []))
        [.drop 0] (Store.empty.set 0 (.cont ([] ++ [.handleF Capture.empty logsClauses]))))
      (some (.io "File.readTextIn" [.checked logsTarget] (.err "IO") [logsTarget]))
      (.error ["IO"] [.drop 0] (Store.empty.set 0 (.cont ([] ++ [.handleF Capture.empty logsClauses])))) ∧
    Eff.Allows σ0 (table p).effKind logsBound "File.Read" logsTarget := by
  have hreach : Steps (core p) (table p) σ0 (.run handleLogsClosure [] Store.empty) []
      (.run (Closure.mk (Capture.empty.extendMany ([.checked dataTarget] ++ [.loc 0])) (logsRead.substTy [] []))
        [.drop 0] (Store.empty.set 0 (.cont ([] ++ [.handleF Capture.empty logsClauses])))) :=
    .cons (.E_Handle rfl)
      (.cons (.E_OpPrim (rs := [dataRange]) (k1 := []) (k2 := []) (c := .mk (.prim "File.readTextIn") 1 0 logsRead)
        rfl rfl (Or.inl rfl) ⟨rfl, by decide, by simp [NoHandler]⟩ rfl rfl) .nil)
  have hstep : Step (core p) (table p) σ0
      (.run (Closure.mk (Capture.empty.extendMany ([.checked dataTarget] ++ [.loc 0])) (logsRead.substTy [] []))
        [.drop 0] (Store.empty.set 0 (.cont ([] ++ [.handleF Capture.empty logsClauses]))))
      (some (.io "File.readTextIn" [.checked logsTarget] (.err "IO") [logsTarget]))
      (.error ["IO"] [.drop 0] (Store.empty.set 0 (.cont ([] ++ [.handleF Capture.empty logsClauses])))) :=
    .E_IOErr (rs := [logsRange]) rfl rfl (Or.inl rfl) (by simp [NoHandler])
      (Or.inl ⟨.readText, by decide, rfl, ⟨.readText, rfl, rfl, rfl, .err "IO", logsTarget, rfl, rfl, rfl,
        by intro h; cases h⟩⟩)
  refine ⟨hreach, hstep, ?_⟩
  obtain ⟨hf, hp, he, hc, ht⟩ := program_facts p
  obtain ⟨e, l, hsig, hop, hall⟩ := reachable_target_sound _ _ _ hf hp he hc ht _ _ _
    (handleLogsClosure_typed p) (handleLogs_start p) _ _ _ _ _ _ _ hreach hstep
  rw [sig_read] at hsig
  cases hsig
  simp [ScopeSignatures.readTextIn, ScopeSignatures.ioIn] at hop
  subst hop
  exact hall logsTarget (List.mem_singleton_self _)

end
end Benitoite.Release.Refinement.Surface.TargetStepExamples
