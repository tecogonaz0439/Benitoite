import Benitoite.Release.Refinement.SurfaceTargetReachExamples

/-!
# 観測を持つ IO の事象へ到達する表層の main と、誤った規則の反例

`function main() -> Unit with {File.Read} = { File.readText(path); }` を、標準の型の宣言を収集した表層の
プログラムとして置く（path は文字列のリテラル）。範囲付きのパス操作と Top のパスの読取りを持つ実例の表
（`ExternalModels.targets`）の下で、表層の対象健全性の全前提を満たし、開始状態から観測が空でない読取りの事象へ
到達する（`main_observed`）。

同じ main を、効果の名前だけを照合して範囲を照合しない誤った規則（`NameOnlyCovers`）は効果
`{File.Read["/data/**"]}` で受け入れるが、`/etc/passwd` を読む main の実行は、その効果が許さない対象を観測する
（`wrong_rule_unsound`）。本番の規則（範囲を被覆で照合する）は、到達先の対象健全性から、この main をその効果で
型付けない（`narrow_rejected`。設計書 01-12「確かめる性質」、07-04「証明する性質」）。
-/

namespace Benitoite.Release.Refinement.Surface.TargetObservedExamples
noncomputable section
open StandardModel

/-- `File.readText(path: p)`。 -/
def readCall (p : String) : Expr :=
  .call (.primName "File.readText" [] [] []) [none] [0] (.cons (.literal (.string p)) .nil)

/-- main の宣言した効果 `{File.Read}`。 -/
def readEff : Eff := Eff.single "File.Read"

/-- 読取りの結果型。 -/
abbrev readRet : Ty := ScopeSignatures.resultTy (.base .string) (.opaque "IOError" .top)

def mainDef (p : String) : Def :=
  { Examples.mainDef with eff := readEff, body := .lastDiscard (readCall p) }

/-- 標準の型の宣言と外部宣言を収集し、利用者は p を読む main を書く。 -/
def source (p : String) : Program :=
  { MainExamples.source positiveExternals with defs := fun f => if f = "main" then some (mainDef p) else none }

/-- 演算子の表。 -/
abbrev op : OpPrim := fun _ _ => none
/-- 脱糖したプログラム。 -/
abbrev core (p : String) : Refinement.Program := desugarProgram op (source p)
/-- 範囲付きのパス操作と Top のパスの読取りを持つ実例の表。 -/
abbrev table (p : String) : Builtins := ExternalModels.targets (core p)

private theorem readSig_tel :
    ModelTargets.readTextSig.tel = .param "path" (.base .string) (.done readRet readEff) := rfl

private theorem mainDef_tel (p : String) : (mainDef p).toFunDecl.tel = .done (.base .unit) readEff := rfl

private theorem main_annotation (P : Refinement.Program) (Γ : Ctx := []) :
    Ty.Annotation P [] Γ (.dependentFn (.done (.base .unit) readEff)) :=
  ⟨by simp [readEff,Ty.WF,Tel.WF,Ty.WFList,Eff.WF,Eff.single,Eff.Canonical,Eff.norm,Ty.normTys],by trivial,by trivial⟩

private theorem result_arity (p : String) : (source p).declarations.core.DataArity "Result" 2 :=
  ((http_declarations positiveExternals).file ScopeDeclarations.result (by simp [ScopeDeclarations.file])).1

private theorem ret_annotation (p : String) (Γ : Ctx) :
    Ty.Annotation (source p).declarations.core [] Γ readRet :=
  ⟨by simp [Ty.WF, Ty.WFList, RangeIx.WF],
    by simp [Ty.Sorted, sortedTys],
    by simp [Ty.Declared, declaredTys]; exact result_arity p⟩

private theorem done_annotation (p : String) (Γ : Ctx) :
    Ty.Annotation (source p).declarations.core [] Γ (.dependentFn (.done readRet readEff)) :=
  ⟨⟨(ret_annotation p Γ).wf, by simp [readEff,Eff.WF,Eff.single,Eff.Canonical,Eff.norm,Ty.WFList]⟩,
    ⟨(ret_annotation p Γ).sorted, by simp [readEff,Eff.single,sortedEff,sortedTys]⟩,
    ⟨(ret_annotation p Γ).declared, by simp [readEff,Eff.single,declaredEff,declaredTys]⟩⟩

/-- 表層の整形式。型の宣言は標準の宣言の整形式を引き継ぐ。 -/
theorem wellFormed (p : String) : (source p).WellFormed where
  types := (MainExamples.wellFormed positiveExternals positive_wf).types
  defs := by
    intro f d hd
    change (if f = "main" then some (mainDef p) else none) = some d at hd
    split at hd
    · cases hd
      refine ⟨by simp [mainDef,Examples.mainDef,FunDecl.coreNames,FunDecl.coreParams,FunDecl.dictTys,internalNames,NamesWF],?_,
        by simp [mainDef,Examples.mainDef,readCall,Block.Scoped,Expr.Scoped,Exprs.Scoped,scopedTypes,scopedRows]⟩
      change SignatureScopedR _ [] [] 0 (.done (.base .unit) readEff)
      refine ⟨⟨(main_annotation (source p).declarations.core).wf,?_,?_⟩,?_,?_,
        (main_annotation (source p).declarations.core).range_empty⟩
      all_goals simp [readEff,Eff.single,Ty.RowsIn,Tel.RowsIn,Eff.RowsIn,Ty.RowsInList,Ty.RangesScoped,
        Tel.RangesScoped,Eff.RangesScoped,rangesScopedTypes,Ty.HasKind,kindsTel,kindsEff,kindsList,RangeIx.WF]
    · cases hd
  impls := by intro i id hi; cases hi
  accessors := by intro f c k h; cases h
  testers := by intro f c h; cases h

private abbrev readTel : Tel := .param "path" (.base .string) (.done readRet readEff)

private theorem read_instR : Tel.instR [] ModelTargets.readTextSig.tel = readTel := by
  simp [readSig_tel, Tel.instR, Tel.substRAt, Tel.mapRanges, Tel.norm, Ty.norm, Eff.norm, readEff, Eff.single,
    readRet, ScopeSignatures.resultTy, Ty.normTys, 
    ]

private theorem read_instantiated : instantiatedTel readTel [] [] = readTel := by
  simp [instantiatedTel, Tel.bind, Tel.rawBind, Ty.rawBind, Eff.rawBind, typeEnvAt, substAtoms_nil, instAtoms_nil,
    rowFails, Tel.norm, Ty.norm, Ty.normTys, Eff.norm, readEff, Eff.single, readRet, ScopeSignatures.resultTy]

private theorem read_admissible (Q : NoFailCtx) : PrimitiveAdmissible [] 0 ModelTargets.readTextSig Q [] [] := by
  constructor
  · rfl
  · simp [ModelTargets.readTextSig, ScopeSignatures.unscopedIO]
  · simp
  · rfl
  · simp
  · simp [ModelTargets.readTextSig, ScopeSignatures.unscopedIO, Eff.single, Eff.RowsIn, Ty.RowsInList]
  · simp [ModelTargets.readTextSig, ScopeSignatures.unscopedIO, Qsig, QTys, QTy, QEff, Eff.single,
      Benitoite.Release.Qempty]
  · simp [ModelTargets.readTextSig, ScopeSignatures.unscopedIO, Qsig, QTys, QTy, QEff, Eff.single,
      Benitoite.Release.Qempty, RowTransport]
  · simp [readSig_tel, Tel.RowsIn, Ty.RowsIn, Ty.RowsInList, Eff.RowsIn, readEff, Eff.single, readRet,
      ScopeSignatures.resultTy]

private theorem read_instance (p : String) :
    SignatureInstance (source p).declarations.core [] [] (Tel.instR [] ModelTargets.readTextSig.tel) [] [] [] := by
  rw [read_instR]
  constructor
  · simp [readEff, Ty.WF, Tel.WF, Ty.WFList, Eff.WF, Eff.single, Eff.Canonical, Eff.norm, Ty.normTys, RangeIx.WF]
  · simp [TypeAnnotations]
  · exact ⟨rfl, by intro i a k ha; cases i <;> cases ha⟩
  · simp [RowAnnotations]
  · simp
  · rw [read_instantiated]
    have h := done_annotation p (Ctx.extend [] (.base .string))
    exact ⟨⟨by simp [Ty.WF], h.wf⟩, ⟨trivial, h.sorted⟩, ⟨trivial, h.declared⟩⟩

private theorem read_head (p : String) (Q : NoFailCtx) :
    CallHeadTy (source p).declarations (table p) Q [] [] (.primName "File.readText" [] [] []) readTel [] := by
  have h := CallHeadTy.prim (D := (source p).declarations) (B := table p) (Q := Q) (C := []) (Γ := [])
    (b := "File.readText") (s := ModelTargets.readTextSig) (ts := []) (es := []) (rs := []) rfl
    ⟨rfl, by simp, by simp, Or.inl (by simp)⟩
    (by simp [ModelTargets.readTextSig, ScopeSignatures.unscopedIO, NamesWF]) (read_admissible Q) (read_instance p)
  simpa only [List.map_nil, read_instR, read_instantiated] using h

private theorem empty_sub (e : Eff) : Eff.Sub Eff.empty e :=
  ⟨by intro a ha; simp [Eff.empty,Eff.mem,Eff.test,Eff.atoms] at ha,
    by intro t ht; obtain ⟨u,hu,_⟩ := ht; simp [Eff.empty,Eff.fails] at hu⟩

private theorem read_typed (p : String) (Q : NoFailCtx) :
    HasTypeQ (source p).declarations (table p) op Q [] [] [] [] (some (.base .unit)) .other (readCall p) readRet
      readEff := by
  apply HasTypeQ.E_CallDirect (r := readRet) (e := readEff) (read_head p Q)
  · simp [CallOk, Tel.names, telBinders]
  · exact .cons (.E_Sub (.E_Literal trivial) .refl (empty_sub _).covers ⟨trivial, trivial, trivial⟩) .nil
  · simp [Tel.shiftV, bindParams, liftMany_one, boundVars, recordFields, fieldAt, Ty.shiftV,
      Eff.shiftV, readEff, Eff.single, readRet, ScopeSignatures.resultTy]
    apply ValsTel.param
    · exact ⟨by simp [Ty.WF], trivial, trivial⟩
    · exact .var rfl (by simp [Ordinary, Literal.toConst, Const.type, Ty.shiftV, Ty.core])
    · exact .refl
    · simpa [Tel.bind, Tel.rawBind, Tel.argumentsEnv, Ty.rawBind, Eff.rawBind, valEnv, typeEnvAt,
        substAtoms_nil, instAtoms_nil, rowFails, Tel.norm, Ty.norm, Ty.normTys, Eff.norm, Tel.shiftV, Ty.shiftV,
        Eff.shiftV, Ctx.extend, liftMany_one, readEff, Eff.single, Literal.toConst, Const.type, readRet,
        ScopeSignatures.resultTy] using
        (ValsTel.done (D := (source p).declarations) (B := table p) (C := []) (Γ0 := []) (k := 1)
          (Γ := [some (.base .string)]) (Φ := []) (a := readRet) (e := readEff)
          (done_annotation p [some (.base .string)]))
  · simp [readRet, ScopeSignatures.resultTy, Ty.shiftV]
    exact .refl
  · simp [Eff.shiftV, readEff, Eff.single]
    exact Eff.Covers.refl _ _ _
  · exact ret_annotation p []

/-- 表層の型付け。読取りの直接の呼出しの効果は main の宣言の効果に等しい。 -/
theorem wellTyped (p : String) : (source p).WellTyped (table p) op where
  variance := (variance_valid positiveExternals).sameTypes ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩
  defs := by
    intro f d hd
    change (if f = "main" then some (mainDef p) else none) = some d at hd
    split at hd
    · cases hd
      refine ⟨by simp [mainDef, Examples.mainDef, FunDecl.coreNames, FunDecl.coreParams, FunDecl.dictTys,
          internalNames, NamesWF], ?_, by rw [mainDef_tel]; exact (main_annotation _).range_empty, ?_⟩
      · rw [mainDef_tel]; simp [Ty.HasKind, kindsTel, kindsEff, kindsList, readEff, Eff.single]
      · rw [mainDef_tel]; exact .done (.B_LastDiscard (read_typed p _))
    · cases hd
  impls := by intro i id hi; cases hi
  effects := ⟨fun _ _ _ h => by simp [Program.declarationsFor, Program.declarations, Declarations.core, source,
      MainExamples.source, Examples.mainProgram] at h,
    fun _ _ h => by simp [Program.declarationsFor, Program.declarations, Declarations.core, source,
      MainExamples.source, Examples.mainProgram] at h,
    fun _ _ h => by simp [Program.declarationsFor, Program.declarations, Declarations.core, source,
      MainExamples.source, Examples.mainProgram] at h⟩

/-- 範囲付きのモデルが読む Result と Scope.ScopeError の宣言。 -/
theorem hasFile (p : String) : ScopeDeclarations.HasFile (core p) := (http_declarations positiveExternals).file

/-- main の宣言の形。 -/
theorem hasMain (p : String) : (source p).HasMain readEff := ⟨mainDef p, rfl, rfl, rfl, rfl, rfl, rfl, Or.inl rfl, rfl⟩

/-- 環境の束縛。 -/
theorem ready (p : String) :
    TargetReachExamples.environment.Ready (core p) (table p) (.run mainClosure [] Store.empty) := by
  refine ⟨by simp [PathEnv.Valid,TargetReachExamples.environment,Scope.Domain.PathWordWF], ?_⟩
  intro r _
  cases r with
  | base b => cases b <;> exact ⟨[],rfl⟩
  | secrets => rfl

private def pathValue (p : String) : Refinement.Val := .const (.string p)
private def readComp : Comp := .app (.prim "File.readText" [] [] []) [.var 0]
private def restComp : Comp := .ret (.const .unit)

/-- 開始状態から、main の呼出し・二つの let・値の返却で読取りの呼出しへ進み、読取りの事象を伴って遷移する。
観測は実引数の文字列を絶対形として解析したパスである（`ModelTargets.readObs`）。 -/
theorem reach (p : String) :
    Benitoite.Release.Refinement.Steps (core p) (table p) TargetReachExamples.environment
      (.run mainClosure [] Store.empty) []
      (.run ((Closure.mk Capture.empty readComp).apply [pathValue p])
        [.letF (Closure.mk Capture.empty restComp), .mark] Store.empty) ∧
    Benitoite.Release.Refinement.Step (core p) (table p) TargetReachExamples.environment
      (.run ((Closure.mk Capture.empty readComp).apply [pathValue p])
        [.letF (Closure.mk Capture.empty restComp), .mark] Store.empty)
      (some (.io "File.readText" [pathValue p] (.err "IO") (ModelTargets.readObs [pathValue p])))
      (.error ["IO"] [.letF (Closure.mk Capture.empty restComp), .mark] Store.empty) :=
  ⟨.cons (.E_Fun (rs := []) rfl rfl rfl rfl rfl)
    (.cons (.E_Let rfl) (.cons (.E_Let rfl) (.cons (.E_Return rfl) .nil))),
   .E_IOErr (rs := []) rfl rfl (Or.inl rfl) (by simp [NoHandler]) (Or.inr (Or.inr (Or.inr ⟨rfl, .err "IO", rfl⟩)))⟩

private theorem data_obs : ModelTargets.readObs [pathValue "/data/a.txt"] = [.path ["data", "a.txt"]] := by
  decide +kernel

private theorem passwd_obs : ModelTargets.readObs [pathValue "/etc/passwd"] = [.path ["etc", "passwd"]] := by
  decide +kernel

/-- 表層の対象健全性の全前提を満たす main の開始状態から、観測 `/data/a.txt` を持つ読取りの事象へ到達し、その観測は
main の宣言した効果が許す（`surface_target_sound` の適用）。 -/
theorem main_observed :
    (∃ s s', Benitoite.Release.Refinement.Steps (core "/data/a.txt") (table "/data/a.txt")
        TargetReachExamples.environment (.run mainClosure [] Store.empty) [] s ∧
      Benitoite.Release.Refinement.Step (core "/data/a.txt") (table "/data/a.txt") TargetReachExamples.environment s
        (some (.io "File.readText" [.const (.string "/data/a.txt")] (.err "IO") [.path ["data", "a.txt"]])) s') ∧
    ∃ e l, (table "/data/a.txt").sig "File.readText" = some e ∧ e.opEff = some l ∧
      ∀ t ∈ [Scope.Domain.Target.path ["data", "a.txt"]],
        Eff.Allows TargetReachExamples.environment (table "/data/a.txt").effKind readEff l t := by
  obtain ⟨hs, hst⟩ := reach "/data/a.txt"
  rw [data_obs] at hst
  exact ⟨⟨_, _, hs, hst⟩, surface_target_sound (wellFormed _) (wellTyped _) (ExternalModels.targets_core _ (hasFile _))
    (ExternalModels.targets_scope _ (hasFile _)).toTargetAgreement (hasMain _) (ready _) _ _ _ _ _ _ _ hs hst⟩

/-! ## 誤った規則の反例 -/

/-- 効果の名前だけを照合し、範囲を照合しない誤った包含。内側の効果の各名前の原子について、外側が同じ名前の原子を
どれかの範囲で持てばよいとする。本番の規則は原子の範囲を被覆で照合する（`Eff.Covers`）。 -/
def NameOnlyCovers (outer inner : Eff) : Prop :=
  ∀ l ix, inner.mem (.name l ix) → ∃ jx, outer.mem (.name l jx)

/-- 誤った規則による型付け。本番の型付けで得た効果を、誤った包含で上限へ広げる。 -/
def WrongTyped (P : Refinement.Program) (B : Builtins) (q : Closure) (ε : Eff) : Prop :=
  ∃ a e, ClosureTy P B StoreTy.empty [] none q a e ∧ NameOnlyCovers ε e

/-- 上限 `{File.Read["/data/**"]}`。 -/
def dataRead : Eff :=
  .mk (fun a => decide (a = .name "File.Read" (.fixed (.absolute (.path (.tree ["data"])))))) []

private theorem passwd_not_allowed (σ : PathEnv) (κ : EffName → Option Scope.Domain.Kind) :
    ¬ Eff.Allows σ κ dataRead "File.Read" (.path ["etc", "passwd"]) := by
  rintro ⟨k, r, -, hm, ht⟩
  simp [dataRead, Eff.mem, Eff.test, Eff.atoms] at hm
  subst hm
  revert ht
  simp [RangeExpr.Mem, RangeExpr.resolve, Scope.Domain.Range.Mem, Scope.Domain.PathPattern.Matches]

/-- 誤った規則のもとでは対象健全性が破れる。誤った規則は `/etc/passwd` を読む main を上限 `{File.Read["/data/**"]}`
で型付け、開始状態から到達した読取りの事象は `/etc/passwd` を観測し、その観測は上限が許さない。 -/
theorem wrong_rule_unsound :
    WrongTyped (core "/etc/passwd") (table "/etc/passwd") mainClosure dataRead ∧
    (∃ s s', Benitoite.Release.Refinement.Steps (core "/etc/passwd") (table "/etc/passwd")
        TargetReachExamples.environment (.run mainClosure [] Store.empty) [] s ∧
      Benitoite.Release.Refinement.Step (core "/etc/passwd") (table "/etc/passwd") TargetReachExamples.environment s
        (some (.io "File.readText" [.const (.string "/etc/passwd")] (.err "IO") [.path ["etc", "passwd"]])) s') ∧
    ¬ Eff.Allows TargetReachExamples.environment (table "/etc/passwd").effKind dataRead "File.Read"
      (.path ["etc", "passwd"]) := by
  obtain ⟨a, -, hq, -⟩ := main_start (B := table "/etc/passwd") (op := op) (wellFormed "/etc/passwd")
    (hasMain "/etc/passwd") (ready "/etc/passwd")
  obtain ⟨hs, hst⟩ := reach "/etc/passwd"
  rw [passwd_obs] at hst
  refine ⟨⟨a, readEff, hq, ?_⟩, ⟨_, _, hs, hst⟩, passwd_not_allowed _ _⟩
  intro l ix hm
  simp [readEff, Eff.single, Eff.mem, Eff.test, Eff.atoms] at hm
  obtain ⟨rfl, -⟩ := hm
  exact ⟨.fixed (.absolute (.path (.tree ["data"]))), by simp [dataRead, Eff.mem, Eff.test, Eff.atoms]⟩

/-- 本番の規則は、同じ main を上限 `{File.Read["/data/**"]}` で型付けない（到達先の対象健全性から）。 -/
theorem narrow_rejected (a : Ty) :
    ¬ ClosureTy (core "/etc/passwd") (table "/etc/passwd") StoreTy.empty [] none mainClosure a dataRead := by
  intro hq
  have hc := ExternalModels.targets_core _ (hasFile "/etc/passwd")
  obtain ⟨hf, hp, he⟩ := desugar_typed (wellFormed "/etc/passwd") (wellTyped "/etc/passwd") hc.values
  obtain ⟨-, -, -, hstart⟩ := main_start (B := table "/etc/passwd") (op := op) (wellFormed "/etc/passwd")
    (hasMain "/etc/passwd") (ready "/etc/passwd")
  obtain ⟨hs, hst⟩ := reach "/etc/passwd"
  rw [passwd_obs] at hst
  obtain ⟨e, l, hsig, hop, hall⟩ := reachable_target_sound _ _ _ hf hp he hc
    (ExternalModels.targets_scope _ (hasFile _)).toTargetAgreement _ a dataRead hq hstart _ _ _ _ _ _ _ hs hst
  have he' : e = ModelTargets.readTextSig := by
    have : (table "/etc/passwd").sig "File.readText" = some ModelTargets.readTextSig := rfl
    rw [this] at hsig; exact (Option.some.inj hsig).symm
  subst he'
  have hl : l = "File.Read" := by
    simp [ModelTargets.readTextSig, ScopeSignatures.unscopedIO] at hop; exact hop.symm
  subst hl
  exact passwd_not_allowed _ _ (hall _ (List.mem_singleton_self _))

end
end Benitoite.Release.Refinement.Surface.TargetObservedExamples
