import Benitoite.Release.Lemmas.TargetPropagation
import Benitoite.Release.ModelTargets

/-!
# ハンドラと対象の例（L30.3）

L00.07 の例 3a・3b・3c の本番版。L20.7 の実例の表 `ModelTargets.Examples.B`（`File.Write` の操作は
`File.writeTextIn` だけ）と本番の型付け・遷移で置く。

- 3a（別の対象へ書く節）: 保護本体が `/data/**` へ書き、節が `/logs/**` へ書く。節の添字は規則の値 `/data/**` で、
  外側の上限は `{File.Write[/logs/**]}` だけになる。外側の上限は節が書く対象を許し、保護本体の対象を許さない。
  初期状態から到達した節の IO の状態で、事象の観測（`/logs/l.txt`）が初期の上限に許されることを、本番の保存と
  伝播の補題（`ContTy.allows_end_of_prim_call`）で示す。
- 3b（捕捉した引数を転送する節）: 節が捕捉した引数（節の添字 `/data/**` の型を持つ）を同じ範囲の書き込みへ渡すと、
  外側の上限は `File.Write[/data/**]` を持ち、節の書き込みはその上限で型付く。
- 3c（利用者の操作）: 利用者のエフェクト `Report` の操作 `save` の引数の型は宣言の閉じた範囲で決まり、節の添字に
  よらない（`opSigAt_user`）。節が `File.writeTextIn` で書くと、外側の上限は `File.Write[/data/reports/**]` だけで、
  `Report` の原子を含まない。利用者の操作の型付け `V_Op` と遷移 `E_Op` は変えていない。
-/

namespace Benitoite.Release.HandlerTargetExamples

open Benitoite.Release
open Benitoite.Release.ModelTargets
open Benitoite.Release.ModelTargets.Examples
open Scope.Domain (Range Target)

/-! ## 共通の部品 -/

/-- `/logs/**`。 -/
def logsR : Range := .path (.tree ["logs"])
/-- `/logs/l.txt`。 -/
def logT : Target := .path ["logs", "l.txt"]

/-- `File.writeTextIn` の結果の型 `Result[Unit, IOError]`。 -/
abbrev writeRet : Ty := .data "Result" writeTys

theorem write_admissible_logs : B.RangeAdmissible "File.writeTextIn" TargetTable.writeTextIn [logsR] := by
  refine ⟨⟨?_, ?_, Or.inr ⟨Or.inl rfl, rfl⟩⟩, ?_⟩
  · exact ⟨by decide, Scope.Domain.Range.fitsKinds_nil⟩
  · intro r hr; simp only [List.mem_singleton] at hr; subst hr; decide
  · intro r hr; simp only [List.mem_singleton] at hr; subst hr; decide

theorem write_params_at (r : Range) :
    (TargetTable.writeTextIn.inst [r]).params.map (Ty.subst [] []) =
      [.opaque "Scope.PathIn" (.fixed r), .base .string] := by
  simp [TargetTable.writeTextIn, TargetTable.ioIn, TargetTable.pathIn, Ty.instTarget, Scope.Signature.Ix.inst,
    Ty.subst, Ty.substAt]

theorem write_eff_at (r : Range) : Eff.substAt 0 [] [] (TargetTable.writeTextIn.inst [r]).eff =
    Eff.singleAt "File.Write" (.fixed r) := by
  rw [PrimSig.inst_eff]
  simp only [TargetTable.writeTextIn, TargetTable.ioIn, Eff.instR_singleAt]
  exact substAt_singleAt _ _

/-- `File.writeTextIn[;;r](w, v)` の型付け。どの環境・どの R でも、結果は `Result[Unit, IOError]`、効果は
`{File.Write[r]}` である。 -/
theorem writeCall_typed {P : Program} {Ψ : StoreTy} {Γ : List (Option Ty)} {R : Option Ty} {r : Range}
    {w v : Val} (hr : B.RangeAdmissible "File.writeTextIn" TargetTable.writeTextIn [r])
    (hw : HasTypeVQ P B Ψ Qempty [] Γ w (.opaque "Scope.PathIn" (.fixed r)))
    (hv : HasTypeVQ P B Ψ Qempty [] Γ v (.base .string)) :
    HasTypeCQ P B Ψ Qempty [] Γ R (.app (.prim "File.writeTextIn" [] [] [r]) [w, v]) writeRet
      (Eff.singleAt "File.Write" (.fixed r)) := by
  have hpa : PrimitiveAdmissible [] (TargetTable.writeTextIn.inst [r]) Qempty [] [] :=
    PrimitiveAdmissible.of_noRows_inst write_scoped (by simp [TargetTable.writeTextIn, TargetTable.ioIn, PrimSig.nranges]) rfl rfl rfl (by simp)
  have hval := HasTypeVQ.V_Prim (P := P) (B := B) (Ψ := Ψ) (Q := Qempty) (C := []) (Γ := Γ)
    (b := "File.writeTextIn") (s := TargetTable.writeTextIn) (rs := [r]) (ts := []) (es := [])
    sig_write hr ⟨rfl, by simp [TargetTable.writeTextIn, TargetTable.ioIn]⟩ hpa
  rw [fnTy_eq] at hval
  have hargs : HasTypeVsQ P B Ψ Qempty [] Γ [w, v]
      ((TargetTable.writeTextIn.inst [r]).params.map (Ty.subst [] [])) := by
    rw [write_params_at]
    exact .cons hw (.cons hv .nil)
  have h := HasTypeCQ.C_App (Δ := []) (R := R) hval hargs
  rw [writeTextIn_ret, write_eff_at] at h
  exact h

/-- `Result[Unit, IOError]` は正規形であり、番号 0 のずらしで変わらない。 -/
theorem writeRet_shift : Ty.shift 0 0 writeRet = writeRet := by
  rw [Ty.shift_zero_norm]
  exact Ty.WF.canonical (nr := 0) (n := 0) _ (by simp [writeTys, TargetTable.ioErrorTy, Ty.WF, Ty.WFList])

/-- 名前の原子だけの効果は番号 0 のずらしで変わらない。 -/
theorem singleAt_shift (l : EffName) (ix : Scope.Signature.Ix) : Eff.shift 0 0 (Eff.singleAt l ix) = Eff.singleAt l ix := by
  rw [Eff.shift_zero_norm]
  exact Eff.canonical_ofAtoms _

theorem singleAt_wf (l : EffName) (r : Range) : Eff.WF 0 0 (Eff.singleAt l (.fixed r)) := by
  simp [Eff.singleAt, Eff.ofAtoms, Eff.WF, Ty.WFList]

/-- `File.Write` の操作は `File.writeTextIn` だけなので、その節を持つ `handle` は `File.Write` のどの範囲の原子も
処理する（名前全体の除去）。 -/
theorem mem_handled_write {P : Program} (hP : P.effects "File.Write" = none) {h : List Clause}
    (hh : handles h (.prim "File.writeTextIn") = true) (ix : Scope.Signature.Ix) :
    Eff.mem (handled P B h) (.name "File.Write" ix) := by
  have he : B.effects "File.Write" = some ["File.writeTextIn"] := by simp [B, builtins, stateEff]
  simp [Eff.mem, Eff.test, Eff.atoms, Eff.ofAtoms, handled, effOps, hP, he, hh]

/-! ## 3a: 別の対象へ書く節 -/

/-- 保護本体の効果 `{File.Write[/data/**]}`（L20.7 の `ioCall` の効果）。 -/
abbrev bodyData : Eff := Eff.singleAt "File.Write" dataTree

/-- 外側の上限 `{File.Write[/logs/**]}`。 -/
abbrev logsBound : Eff := Eff.singleAt "File.Write" (.fixed logsR)

/-- 節の本体: `File.writeTextIn[;;/logs/**](checked(/logs/l.txt), "log")`。捕捉した引数を使わず、再開しない。 -/
def logCall : Comp := .app (.prim "File.writeTextIn" [] [] [logsR]) [.checked logT, str "log"]

/-- `File.writeTextIn` の節（引数 2、型引数 0）。 -/
def logClause : Clause := .mk (.prim "File.writeTextIn") 2 0 logCall

def hLog : List Clause := [logClause]

/-- `handle File.writeTextIn[;;/data/**](checked(/data/a.txt), "x") with { writeTextIn(p, s) k ⇒ logCall }`。 -/
def handleLog : Comp := .handle ioCall hLog

theorem bodyData_rule : bodyData.ClauseRangeIs "File.Write" range := by
  refine ⟨fun i h => ?_, (Eff.mem_singleAt _ _ _).mpr rfl, fun ix h => ?_⟩
  · rw [Eff.mem_singleAt] at h; cases h
  · rw [Eff.mem_singleAt] at h; cases h; rfl

/-- 節の添字 `/data/**` で具体化した `File.writeTextIn` の操作の型。捕捉した引数は `PathIn["/data/**"]` を持つ。 -/
def sgData : OpSig :=
  ⟨[], ["path", "text"], [.opaque "Scope.PathIn" (.fixed range), .base .string], writeRet, "File.Write"⟩

/-- 保護本体の効果 `{File.Write[/data/**]}` のもとで、節の添字は規則の値 `/data/**`（Top でない）を選べる。 -/
theorem clauseSig_data {P : Program} : ClauseSig P B bodyData (.prim "File.writeTextIn") sgData := by
  refine ⟨range, Or.inr ⟨"File.writeTextIn", TargetTable.writeTextIn, "File.Write", rfl, sig_write, rfl,
    bodyData_rule⟩, ?_⟩
  simp [opSigAt, sig_write, sgData, TargetTable.writeTextIn, TargetTable.ioIn, TargetTable.pathIn,
    TargetTable.resultTy, TargetTable.ioErrorTy, writeTys, PrimSig.nranges, Ty.instTarget, Scope.Signature.Ix.inst]

theorem log_admissible : B.RangeAdmissible "File.writeTextIn" TargetTable.writeTextIn [logsR] :=
  write_admissible_logs

/-- 節の型付け。節の本体は外側の上限 `{File.Write[/logs/**]}` で型付く。 -/
theorem hLog_typed {P : Program} {Ψ : StoreTy} :
    HasTypeClauses P B Ψ [] [] none bodyData hLog writeRet logsBound := by
  refine .cons clauseSig_data (by simp [NamesWF, sgData]) rfl rfl (singleAt_wf _ _) ?_ .nil
  rw [writeRet_shift, singleAt_shift]
  exact writeCall_typed log_admissible (.V_Checked rfl (by decide)) .V_Const

/-- 保護本体の型付け（効果 `{File.Write[/data/**]}`）。 -/
theorem ioCall_typed' {P : Program} {Ψ : StoreTy} :
    HasTypeC P B Ψ [] [] none ioCall writeRet bodyData :=
  writeCall_typed write_admissible (.V_Checked rfl (by decide)) .V_Const

/-- 3a の型付け。外側の上限は `{File.Write[/logs/**]}` だけである。保護本体の `File.Write[/data/**]` は
`handled(H)` が名前全体で除く。 -/
theorem handleLog_typed {P : Program} (hP : P.effects "File.Write" = none) {Ψ : StoreTy} :
    HasTypeC P B Ψ [] [] none handleLog writeRet logsBound := by
  refine .C_Handle ioCall_typed' ⟨fun a ha => ?_, fun t ht => ?_⟩ hLog_typed
  · rw [Eff.mem_singleAt] at ha
    subst ha
    exact (Eff.mem_union _ _ _).mpr (Or.inr (mem_handled_write hP rfl _))
  · simp [Eff.memFail, Eff.singleAt, Eff.ofAtoms, Eff.fails] at ht

/-- 外側の上限は節が書く対象 `/logs/l.txt` を許す。 -/
theorem logsBound_allows_log : B.Allows logsBound "File.Write" logT :=
  ⟨.path, logsR, rfl, (Eff.mem_singleAt _ _ _).mpr rfl, by decide⟩

/-- 外側の上限は保護本体の対象 `/data/a.txt` を許さない（処理した名前の原子は外側に残らない）。 -/
theorem logsBound_not_allows_data : ¬ B.Allows logsBound "File.Write" target := by
  rintro ⟨kd, r, hk, hm, ht⟩
  have hk' : kd = .path := by simp [B, builtins, TargetTable.effKind] at hk; exact hk.symm
  subst hk'
  rw [Eff.mem_singleAt] at hm
  simp only [Atom.name.injEq, Scope.Signature.Ix.fixed.injEq, true_and] at hm
  subst hm
  revert ht
  decide

/-- 保護本体の効果は `/data/a.txt` を許す（捕捉の前の呼び出しの対象）。 -/
theorem bodyData_allows_data : B.Allows bodyData "File.Write" target :=
  ⟨.path, range, rfl, (Eff.mem_singleAt _ _ _).mpr rfl, by decide⟩

/-! ### 3a の実行: 節の IO の観測は初期の上限に許される -/

/-- 例のプログラム（L20.7 の `progOf dataTree`。`File.Write` を宣言しない）。 -/
abbrev P3 : Program := progOf dataTree

theorem handleLog_closed : handleLog.ClosedNoEffVars := by
  simp [handleLog, hLog, logClause, logCall, ioCall, str, Comp.ClosedNoEffVars, Comp.VarsIn, Val.VarsIn,
    Ty.VarsInList, Eff.VarsInList, Val.VarsInList, Clause.VarsInList]

/-- 初期状態 `⟨handleLog, [], ∅⟩` は、初期の計算の効果 `{File.Write[/logs/**]}` を継続の末尾に固定した状態の型付けを持つ。 -/
theorem s0_typed : StateTyE P3 B logsBound (.run handleLog [] Store.empty) :=
  stateTyE_init_eff (progOf_wellFormed dataTree_wf) (progOf_assumptions dataTree).core (handleLog_typed rfl)
    handleLog_closed

/-- E-OpPrim の後のストア（継続の場所 0 に捕捉した継続）。 -/
def σ1 : Store := Store.empty.set 0 (.cont [.handleF hLog])

/-- 節の本体の IO の状態。 -/
def sIO : State := .run logCall [.drop 0] σ1

theorem logCall_inst : (logCall.substTy [] []).instantiate ([.checked target, str "x"] ++ [.loc 0]) = logCall := by
  simp [logCall, Comp.substTy, Comp.instantiate, str, Comp.substTyAt, Val.substTyAt, Val.substTyAtList, Comp.subst,
    Val.subst, Val.substList]

/-- 初期状態から、E-Handle と E-OpPrim（節の添字は `/data/**`）で節の本体の IO の状態へ進む。 -/
theorem reach_io : Steps P3 B (.run handleLog [] Store.empty) sIO := by
  have hop : Step P3 B (.run ioCall [.handleF hLog] Store.empty) none
      (.run ((logCall.substTy [] []).instantiate ([.checked target, str "x"] ++ [.loc 0])) (.drop 0 :: [])
        (Store.empty.set 0 (.cont ([] ++ [.handleF hLog])))) :=
    .E_OpPrim (s := TargetTable.writeTextIn) (k1 := []) (k2 := []) (c := logClause) sig_write (.inl rfl)
      ⟨rfl, rfl, fun _ h => by cases h⟩ rfl rfl
  rw [logCall_inst, List.nil_append] at hop
  exact .step .E_Handle (.step hop .refl)

/-- 保存の定理で、節の本体の IO の状態は同じ末尾の効果 `{File.Write[/logs/**]}` の状態の型付けを持つ。 -/
theorem sIO_typed : StateTyE P3 B logsBound sIO :=
  steps_preserve (progOf_wellFormed dataTree_wf) (progOf_wellTyped dataTree) (progOf_effectsOk dataTree)
    (progOf_assumptions dataTree).core reach_io s0_typed

/-- 節の本体の IO の事象。観測は `/logs/l.txt` 一つである。 -/
theorem sIO_step :
    Step P3 B sIO
      (some (.io "File.writeTextIn" [.checked logT, str "log"] (.val (.con "Ok" writeTys [.const .unit])) [logT]))
      (.run (.ret (.con "Ok" writeTys [.const .unit])) [.drop 0] σ1) :=
  .E_IO (s := TargetTable.writeTextIn) sig_write rfl (fun _ h => by simp at h) (.inr (.inr (.inl ⟨rfl, .inl rfl, rfl⟩)))

/-- 3a の到達先の観測。節の IO の事象の観測は、本番の保存（`steps_preserve`）・伝播（`ContTy.allows_end_of_prim_call`）・
対象一致の条件（`TargetAgreement.obs_allowed`）から、初期の上限 `{File.Write[/logs/**]}` に許される。 -/
theorem sIO_obs_allowed : ∀ t ∈ [logT], B.Allows logsBound "File.Write" t := by
  have hs := sIO_typed
  change StateTyE P3 B logsBound
    (.run (.app (.prim "File.writeTextIn" [] [] [logsR]) [.checked logT, str "log"]) [.drop 0] σ1) at hs
  obtain ⟨Ψ, R, a, b, ε, ε1, -, hm, hε, hk, -⟩ := hs
  obtain ⟨l, hl, hprop⟩ := ContTy.allows_end_of_prim_call (κ := B.effKind) (progOf_effectsOk dataTree)
    (progOf_assumptions dataTree).core hm hε hk sig_write (.inl rfl) (fun _ h => by simp at h)
  obtain ⟨s', hs', htl, hel, had, hw, -, -, hR⟩ := inv_prim_app hm
  rw [sig_write] at hs'
  cases hs'
  obtain ⟨l2, hl2, hobs⟩ := (progOf_assumptions dataTree).obs_allowed (o := .val (.con "Ok" writeTys [.const .unit]))
    (obs := [logT]) sig_write (.inl rfl) hR htl hel had hw (.inr (.inr (.inl ⟨rfl, .inl rfl, rfl⟩)))
  cases hl
  cases hl2
  intro t ht
  exact (hprop _ t (hobs t ht)).2

/-- E-Handle の後の状態（保護本体の IO の呼び出しと、その節を持つ枠）。 -/
def s1 : State := .run ioCall [.handleF hLog] Store.empty

theorem s1_typed : StateTyE P3 B logsBound s1 :=
  steps_preserve (progOf_wellFormed dataTree_wf) (progOf_wellTyped dataTree) (progOf_effectsOk dataTree)
    (progOf_assumptions dataTree).core (.step .E_Handle .refl) s0_typed

/-- 捕捉の枠への伝播（`ContTy.allows_hole_of_split`）。E-Handle の後の状態で、捕捉される呼び出しの対象 `/data/a.txt`
は、処理する枠の穴の効果（節の添字を選ぶ保護本体の効果）に許される。同じ対象は継続の末尾の効果
`{File.Write[/logs/**]}` には許されない（`logsBound_not_allows_data`）。 -/
theorem s1_hole_allows : ∃ Ψ Rh t εh εc, HasTypeClauses P3 B Ψ [] [] Rh εh hLog t εc ∧
    B.Allows εh "File.Write" target := by
  have hs := s1_typed
  change StateTyE P3 B logsBound
    (.run (.app (.prim "File.writeTextIn" [] [] [range]) [.checked target, str "x"]) ([] ++ .handleF hLog :: [])
      Store.empty) at hs
  obtain ⟨Ψ, R, a, b, ε, ε1, -, hm, hε, hk, -⟩ := hs
  obtain ⟨t, εh, εb, εc, Rh, -, -, -, hcl, -, hhole⟩ := hk.allows_hole_of_split (κ := B.effKind) (l := "File.Write") (b0 := "File.writeTextIn")
    (progOf_effectsOk dataTree) rfl (by simp [B, builtins, stateEff]) (List.mem_singleton_self _)
    (fun _ h => by simp at h)
  obtain ⟨s', hs', -, -, -, -, -, hsub, -⟩ := inv_prim_app hm
  rw [sig_write] at hs'
  cases hs'
  rw [write_eff_at] at hsub
  obtain ⟨a1, ha1, ha1c⟩ := hsub.1 _ ((Eff.mem_singleAt _ _ _).mpr rfl)
  obtain ⟨jx, rfl⟩ := ha1c.name_right
  exact ⟨Ψ, Rh, t, εh, εc, hcl,
    hhole target (Eff.allows_of_mem_covers rfl (hε.1 _ ha1) ha1c (by decide))⟩

/-- 同じ到達先で、捕捉の前の呼び出しの対象 `/data/a.txt` は初期の上限に許されない。 -/
example : ¬ B.Allows logsBound "File.Write" target := logsBound_not_allows_data

/-! ## 3b: 捕捉した引数を転送する節 -/

/-- 節の本体: 捕捉した引数 `path`（番号 2。節の添字 `/data/**` の型）と `text`（番号 1）をそのまま
`File.writeTextIn[;;/data/**]` へ渡す。 -/
def fwdCall : Comp := .app (.prim "File.writeTextIn" [] [] [range]) [.var 2, .var 1]

def fwdClause : Clause := .mk (.prim "File.writeTextIn") 2 0 fwdCall

def handleFwd : Comp := .handle ioCall [fwdClause]

/-- 節の添字が `/data/**` なので、捕捉した引数は `PathIn["/data/**"]` の型を持ち、同じ範囲の書き込みへ渡せる。
外側の上限は `{File.Write[/data/**]}` である。 -/
theorem handleFwd_typed {P : Program} {Ψ : StoreTy} :
    HasTypeC P B Ψ [] [] none handleFwd writeRet bodyData := by
  refine .C_Handle ioCall_typed' ⟨fun a ha => ?_, fun t ht => ?_⟩ ?_
  · exact (Eff.mem_union _ _ _).mpr (Or.inl ha)
  · simp [Eff.memFail, Eff.singleAt, Eff.ofAtoms, Eff.fails] at ht
  · refine .cons clauseSig_data (by simp [NamesWF, sgData]) rfl rfl (singleAt_wf _ _) ?_ .nil
    rw [writeRet_shift, singleAt_shift]
    exact writeCall_typed write_admissible (.V_Var (by simp [sgData, binds, shiftEnv]) (by simp))
      (.V_Var (by simp [sgData, binds, shiftEnv]) (by simp))

/-- 転送の節の外側の上限は、捕捉した呼び出しの対象 `/data/a.txt` を許す。 -/
example : B.Allows bodyData "File.Write" target := bodyData_allows_data

/-! ## 3c: 利用者の操作 -/

/-- `/data/reports/**`。 -/
def reportsR : Range := .path (.tree ["data", "reports"])
/-- `/data/reports/2026.txt`。 -/
def reportT : Target := .path ["data", "reports", "2026.txt"]

/-- 利用者のエフェクト `Report` の操作 `save(path: Scope.PathIn["/data/reports/**"], text: String) -> Unit`。引数の型の
範囲は宣言の閉じた範囲である。 -/
def saveDecl : OpDecl := ⟨"Report", [], ["path", "text"], [.opaque "Scope.PathIn" (.fixed reportsR), .base .string],
  .base .unit, []⟩

def progReport : Program :=
  ⟨fun _ => none, resultCons, fun o => if o = "save" then some saveDecl else none,
    fun l => if l = "Report" then some ["save"] else none, fun _ => none, fun _ => none⟩

/-- 保護本体: `save(checked(/data/reports/2026.txt), "x")`。効果は名前だけの `{Report}`。 -/
def saveCall : Comp := .app (.op "save" []) [.checked reportT, str "x"]

/-- 節の本体: `let _ = File.writeTextIn[;;/data/reports/**](path, text) in resume k ()`。 -/
def saveBody : Comp :=
  .letIn (.app (.prim "File.writeTextIn" [] [] [reportsR]) [.var 2, .var 1]) (.resume (.var 1) (.const .unit))

def saveClause : Clause := .mk (.user "save") 2 0 saveBody

def handleSave : Comp := .handle saveCall [saveClause]

/-- 外側の上限 `{File.Write[/data/reports/**]}`。 -/
abbrev reportsBound : Eff := Eff.singleAt "File.Write" (.fixed reportsR)

theorem write_admissible_reports : B.RangeAdmissible "File.writeTextIn" TargetTable.writeTextIn [reportsR] := by
  refine ⟨⟨?_, ?_, Or.inr ⟨Or.inl rfl, rfl⟩⟩, ?_⟩
  · exact ⟨by decide, Scope.Domain.Range.fitsKinds_nil⟩
  · intro r hr; simp only [List.mem_singleton] at hr; subst hr; decide
  · intro r hr; simp only [List.mem_singleton] at hr; subst hr; decide

/-- 利用者の操作の節の操作の型は宣言のとおりで、節の添字によらない（`opSigAt_user`）。 -/
def sgSave : OpSig := ⟨[], ["path", "text"], [.opaque "Scope.PathIn" (.fixed reportsR), .base .string], .base .unit,
  "Report"⟩

theorem opSig_save : opSig progReport B (.user "save") = some sgSave := by
  simp [opSig, progReport, saveDecl, sgSave]

/-- 節の添字をどう選んでも、利用者の操作の節の操作の型は宣言の型である。 -/
theorem opSigAt_save (S : Range) : opSigAt progReport B S (.user "save") = some sgSave := by
  rw [opSigAt_user]; exact opSig_save

theorem saveCall_typed {Ψ : StoreTy} :
    HasTypeC progReport B Ψ [] [] none saveCall (.base .unit) (Eff.single "Report") := by
  have hv := HasTypeVQ.V_Op (P := progReport) (B := B) (Ψ := Ψ) (Q := Qempty) (C := []) (Γ := [])
    (o := "save") (od := saveDecl) (ts := []) (by simp [progReport]) (by simp [NamesWF, saveDecl])
    ⟨rfl, fun i _ _ h => by simp at h⟩
  rw [fnTy_eq, Eff.substAt_single] at hv
  have hargs : HasTypeVs progReport B Ψ [] [] [.checked reportT, str "x"] (saveDecl.params.map (Ty.subst [] [])) := by
    simp only [saveDecl, List.map_cons, List.map_nil, Ty.subst, Ty.substAt]
    exact .cons (.V_Checked rfl (by decide)) (.cons .V_Const .nil)
  have h := HasTypeCQ.C_App (Δ := []) (R := none) hv hargs
  simpa [saveCall, saveDecl, Ty.subst, Ty.substAt] using h

/-- 利用者のエフェクト `Report` の唯一の操作 `save` の節を持つ `handle` は、`Report` を処理する。 -/
theorem mem_handled_report : Eff.mem (handled progReport B [saveClause]) (.nameTop "Report") := by
  simp [Eff.mem, Eff.test, Eff.atoms, Eff.ofAtoms, handled, effOps, progReport, saveClause, handles, Clause.op]

/-- 3c の型付け。外側の上限は `{File.Write[/data/reports/**]}` だけで、`Report` の原子を含まない。 -/
theorem handleSave_typed {Ψ : StoreTy} :
    HasTypeC progReport B Ψ [] [] none handleSave (.base .unit) reportsBound := by
  refine .C_Handle saveCall_typed ⟨fun a ha => ?_, fun t ht => ?_⟩ ?_
  · rw [Eff.mem_single] at ha
    subst ha
    exact (Eff.mem_union _ _ _).mpr (Or.inr mem_handled_report)
  · simp [Eff.memFail, Eff.single, Eff.ofAtoms, Eff.fails] at ht
  · refine .cons (ClauseSig.of_opSig opSig_save) (by simp [NamesWF, sgSave]) rfl rfl (singleAt_wf _ _) ?_ .nil
    rw [singleAt_shift]
    have hu : Ty.shift 0 0 (.base .unit) = .base .unit := by
      rw [Ty.shift_zero_norm]; exact Ty.WF.canonical (nr := 0) (n := 0) _ (by simp [Ty.WF])
    rw [hu]
    refine .C_Let (a := writeRet)
      (writeCall_typed write_admissible_reports (.V_Var (by simp [sgSave, binds, shiftEnv]) (by simp))
        (.V_Var (by simp [sgSave, binds, shiftEnv]) (by simp))) ?_
    exact .C_Resume (b := .base .unit) (by simp [sgSave]) .V_Const

/-- 外側の上限は `Report` の原子を含まない（利用者の操作は節で処理され、外側に残らない）。 -/
theorem reportsBound_no_report : ¬ Eff.mem reportsBound (.nameTop "Report") := by
  rw [Eff.mem_singleAt]
  simp [Atom.nameTop]

/-- 外側の上限は節の書き込みの対象 `/data/reports/2026.txt` を許す。 -/
theorem reportsBound_allows : B.Allows reportsBound "File.Write" reportT :=
  ⟨.path, reportsR, rfl, (Eff.mem_singleAt _ _ _).mpr rfl, by decide⟩

/-- `Report.save` は組み込みの表になく、`Report` は対象の種類も組み込みの操作の一覧も持たない。 -/
theorem save_not_builtin : B.sig "save" = none ∧ B.effKind "Report" = none ∧ B.effects "Report" = none := by
  simp [B, builtins, TargetTable.effKind, stateEff]

end Benitoite.Release.HandlerTargetExamples
