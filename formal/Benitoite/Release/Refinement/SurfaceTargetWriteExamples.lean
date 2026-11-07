import Benitoite.Release.Refinement.SurfaceTargetCoverExamples

/-!
# 範囲付きの検査の結果を照合し、被覆で型付く書き込みの関数を呼ぶ表層の main の対象健全性

標準の型の宣言を収集した表層のプログラムに、次の定義を置く。

- `f(path: PathIn["/data/a.txt"]) -> Unit with {File.Write["/data/**"]}` の本体は
  `File.writeTextIn["/data/a.txt"](path: path, text: "x")` であり、本体の効果 `{File.Write["/data/a.txt"]}` は宣言の効果に
  一原子の被覆でだけ含まれる（`narrow_not_sub`）。
- `g(path: PathIn["/data/a.txt"]) -> Unit with {File.Write["/data/a.txt"]}` は同じ本体を持ち、
  `h(path: PathIn["/data/a.txt"]) -> Unit with {File.Write["/data/**"]}` の本体は `g(path: path)` である。
- `main() -> Unit with {File.Write["/data/**"]}` の本体は
  `match Scope.checkPathIn["/data/a.txt"](pattern: "/data/**", path: "/data/a.txt") { Result.Ok(p) => f(path: p); Result.Error(e) => () }`
  である。表層の構文は検査済みの対象の値を書けないので、f へ渡す値は検査の呼出しの結果の照合から得る。二つの腕は
  標準の宣言の Result の二つの構成子を網羅する（`arms_exhaustive`。Result の構成子の一覧は `result_ctor`）。

範囲付きのパス操作を持つ実例の表（`ExternalModels.targets`）の下で、このプログラムは表層の整形式・型付け・組込みの表の
仮定・main の宣言・環境の束縛を満たし、開始状態から f の本体の書き込みの事象（観測 `/data/a.txt`）へ到達する
（`main_reach`）。到達先の観測は宣言の効果が許し（`main_reach_allowed`）、到達したどの IO の事象の観測にも `/etc/passwd`
は現れない（`main_never_passwd`。表層の対象健全性 `surface_target_sound` の適用。設計書 01-12「確かめる性質」、
07-04「証明する性質」）。
-/

namespace Benitoite.Release.Refinement.Surface.TargetWriteExamples
noncomputable section
open StandardModel Scope.Domain

/-- `/data/a.txt` の範囲。 -/
def exactRange : RangeExpr := .absolute (.path (.exact ["data", "a.txt"]))
/-- `/data/**` の範囲。 -/
abbrev dataRange : RangeExpr := TargetStepExamples.dataRange

/-- main の宣言した効果 `{File.Write["/data/**"]}`。 -/
def mainEff : Eff := .mk (fun a => decide (a = .name "File.Write" (.fixed dataRange))) []
/-- 書き込みの呼出しの効果 `{File.Write["/data/a.txt"]}`。 -/
def narrowEff : Eff := .mk (fun a => decide (a = .name "File.Write" (.fixed exactRange))) []

/-- `PathIn["/data/a.txt"]`。 -/
abbrev pathTy : Ty := .opaque "Scope.PathIn" (.fixed exactRange)
/-- 検査の結果型 `Result[PathIn["/data/a.txt"], Scope.ScopeError]`。 -/
abbrev checkTy : Ty := .data "Result" [pathTy, atErrorType]
/-- 書き込みの結果型。 -/
abbrev writeResult : Ty := .data "Result" [.base .unit, .opaque "IOError" .top]

/-- `Scope.checkPathIn["/data/a.txt"](pattern: "/data/**", path: "/data/a.txt")`。 -/
def checkCall : Expr :=
  .call (.primName "Scope.checkPathIn" [] [] [.fixed exactRange]) [some "pattern", some "path"] [0, 1]
    (.cons (.literal (.string "/data/**")) (.cons (.literal (.string "/data/a.txt")) .nil))

/-- `File.writeTextIn["/data/a.txt"](path: path, text: "x")`（path は局所の番号0）。 -/
def writeCall : Expr :=
  .call (.primName "File.writeTextIn" [] [] [.fixed exactRange]) [some "path", some "text"] [0, 1]
    (.cons (.local 0) (.cons (.literal (.string "x")) .nil))

/-- `f(path: p)`。 -/
def callF : Expr := .call (.funName "f" [] [] []) [some "path"] [0] (.cons (.local 0) .nil)

def okAlt : List Alternative := [⟨.con none "Result.Ok" [.var], [0]⟩]
def errAlt : List Alternative := [⟨.con none "Result.Error" [.var], [0]⟩]

/-- `Result.Ok(p) => f(path: p)`、`Result.Error(e) => ()`。 -/
def arms : Arms := .cons okAlt none (.last callF) (.cons errAlt none (.last .unit) .nil)

def mainDef : Def :=
  { Examples.mainDef with eff := mainEff, body := .last (.matchE (.base .unit) checkCall arms) }

/-- 広い効果を宣言し、本体の書き込みの効果を被覆でだけ含む利用者の関数。 -/
def fDef : Def :=
  { Examples.mainDef with names := ["path"], params := [pathTy], eff := mainEff, body := .lastDiscard writeCall }

/-- 狭い効果を宣言した利用者の関数で、本体の効果は宣言の効果に等しい。 -/
def gDef : Def :=
  { Examples.mainDef with names := ["path"], params := [pathTy], eff := narrowEff, body := .lastDiscard writeCall }

/-- `g(path: path)`。 -/
def callG : Expr := .call (.funName "g" [] [] []) [some "path"] [0] (.cons (.local 0) .nil)

/-- 狭い効果の関数を広い効果の関数から呼び、被覆でだけ型付く。 -/
def hDef : Def :=
  { Examples.mainDef with names := ["path"], params := [pathTy], eff := mainEff, body := .lastDiscard callG }

/-- 定義の表。 -/
def defTable : FunName → Option Def := fun f =>
  if f = "main" then some mainDef else if f = "f" then some fDef else if f = "g" then some gDef
  else if f = "h" then some hDef else none

/-- 標準の型の宣言と外部宣言を収集し、利用者は上の main・f・g・h を書く。 -/
def source : Program := { MainExamples.source positiveExternals with defs := defTable }

/-- 演算子の表。 -/
abbrev op : OpPrim := fun _ _ => none
/-- 脱糖したプログラム。 -/
abbrev core : Refinement.Program := desugarProgram op source
/-- 範囲付きのパス操作を持つ実例の表。 -/
abbrev table : Builtins := ExternalModels.targets core

/-! ## 被覆 -/

theorem exact_covered : dataRange.Covers exactRange := by
  simp only [dataRange, TargetStepExamples.dataRange, exactRange, RangeExpr.covers_absolute]
  decide

/-- 宣言の効果は、書き込みの呼出しの効果を一原子の被覆で覆う。 -/
theorem mainEff_covers (Γ : Ctx) (Φ : List Pred) : Eff.Covers Γ Φ mainEff narrowEff := by
  refine ⟨fun a ha => ⟨.name "File.Write" (.fixed dataRange), by simp [mainEff, Eff.mem, Eff.test, Eff.atoms], ?_⟩,
    fun t ht => ?_⟩
  · have he : a = .name "File.Write" (.fixed exactRange) := by
      simpa [narrowEff, Eff.mem, Eff.test, Eff.atoms] using ha
    subst he
    exact ⟨rfl, exact_covered⟩
  · obtain ⟨u, hu, _⟩ := ht
    simp [narrowEff, Eff.fails] at hu

/-- 被覆だけで含まれる: 書き込みの呼出しの効果は、宣言の効果に構造上の包含では含まれない。 -/
theorem narrow_not_sub : ¬ Eff.Sub narrowEff mainEff := by
  intro h
  have hm := h.1 (.name "File.Write" (.fixed exactRange)) (by simp [narrowEff, Eff.mem, Eff.test, Eff.atoms])
  simp [mainEff, Eff.mem, Eff.test, Eff.atoms, dataRange, TargetStepExamples.dataRange, exactRange] at hm

/-! ## 呼出しの頭 -/

private abbrev checkTel : Tel := .param "pattern" (.base .string) (.param "path" (.base .string) (.done checkTy Eff.empty))
private abbrev writeTel : Tel :=
  .param "path" pathTy (.param "text" (.base .string) (.done writeResult narrowEff))

private theorem check_instantiated :
    instantiatedTel (Tel.instR [exactRange] ScopeSignatures.checkPathIn.tel) [] [] = checkTel := by
  simp [ScopeSignatures.checkPathIn,ScopeSignatures.pureIn,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,
    Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,
    Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
    Eff.norm,typeEnvAt,substAtoms_nil,instAtoms_nil,rowFails,RangeIx.inst,SubstEnv.up,Eff.empty,atErrorType,
    ScopeSignatures.resultTy,ScopeSignatures.pathIn,ScopeSignatures.scopeErrorTy]
  funext x
  simp [mapRangeAtoms]

private theorem write_instantiated :
    instantiatedTel (Tel.instR [exactRange] ScopeSignatures.writeTextIn.tel) [] [] = writeTel := by
  have atoms : mapRangeAtoms (rangeAt 0 [exactRange])
      (fun a => decide (a = .name "File.Write" (.rvar 0))) =
      (fun a => decide (a = .name "File.Write" (.fixed exactRange))) := by
    funext a
    simp [mapRangeAtoms,mapAtomRanges,mapIx,rangeAt,eq_comm]
  simp [ScopeSignatures.writeTextIn,ScopeSignatures.ioIn,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,
    Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,atoms,
    Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
    Eff.norm,typeEnvAt,substAtoms_nil,instAtoms_nil,rowFails,writeResult,writeResult,narrowEff,
    RangeIx.inst,SubstEnv.up]

private theorem table_check : table.sig "Scope.checkPathIn" = some ScopeSignatures.checkPathIn := rfl
private theorem table_write : table.sig "File.writeTextIn" = some ScopeSignatures.writeTextIn := rfl

private theorem result_arity : source.declarations.core.DataArity "Result" 2 :=
  ((http_declarations positiveExternals).file ScopeDeclarations.result (by simp [ScopeDeclarations.file])).1

private theorem error_arity : source.declarations.core.DataArity "Scope.ScopeError" 0 :=
  ((http_declarations positiveExternals).file ScopeDeclarations.scopeError (by simp [ScopeDeclarations.file])).1

theorem checkTy_annotation (Γ : Ctx) : Ty.Annotation source.declarations.core [] Γ checkTy :=
  ⟨by simp [Ty.WF, Ty.WFList, RangeIx.WF, atErrorType],
    by simp [Ty.Sorted, sortedTys, atErrorType],
    by simp [Ty.Declared, declaredTys, atErrorType]; exact ⟨result_arity, error_arity⟩⟩

theorem writeResult_annotation (Γ : Ctx) : Ty.Annotation source.declarations.core [] Γ writeResult := by
  have ar := result_arity
  exact ⟨by trivial,by trivial,⟨⟨2,ar,rfl⟩,by trivial⟩⟩

theorem pathTy_annotation (Γ : Ctx) : Ty.Annotation source.declarations.core [] Γ pathTy :=
  ⟨by simp [Ty.WF, RangeIx.WF], trivial, trivial⟩

private theorem check_ranges : table.RangeAdmissible "Scope.checkPathIn" ScopeSignatures.checkPathIn [exactRange] := by
  refine ⟨rfl,?_,?_,Or.inr ⟨by simp, rfl⟩⟩
  · intro i r k hr hk
    cases i <;> simp [ScopeSignatures.checkPathIn,ScopeSignatures.pureIn] at hr hk
    cases hr; cases hk
    decide
  · intro r hr; simp at hr; subst r
    exact ⟨by decide,by decide⟩

private theorem write_ranges : table.RangeAdmissible "File.writeTextIn" ScopeSignatures.writeTextIn [exactRange] := by
  refine ⟨rfl,?_,?_,Or.inr ⟨by simp, rfl⟩⟩
  · intro i r k hr hk
    cases i <;> simp [ScopeSignatures.writeTextIn,ScopeSignatures.ioIn] at hr hk
    cases hr; cases hk
    decide
  · intro r hr; simp at hr; subst r
    exact ⟨by decide,by decide⟩

private theorem check_admissible (nv : Nat) (Q : NoFailCtx) :
    PrimitiveAdmissible [] nv ScopeSignatures.checkPathIn Q [] [] := by
  constructor
  · rfl
  · simp [ScopeSignatures.checkPathIn, ScopeSignatures.pureIn]
  · simp
  · rfl
  · simp
  · simp [ScopeSignatures.checkPathIn, ScopeSignatures.pureIn, Eff.empty, Eff.RowsIn, Ty.RowsInList]
  · simp [ScopeSignatures.checkPathIn, ScopeSignatures.pureIn, Qsig, QTys, QTy, QEff, Eff.empty,
      Benitoite.Release.Qempty, ScopeSignatures.scopeErrorTy, atErrorType]
  · simp [ScopeSignatures.checkPathIn, ScopeSignatures.pureIn, Qsig, QTys, QTy, QEff, Eff.empty,
      Benitoite.Release.Qempty, RowTransport, ScopeSignatures.scopeErrorTy, atErrorType]
  · simp [ScopeSignatures.checkPathIn,ScopeSignatures.pureIn,PrimSig.tel,signatureTel,Tel.RowsIn,Ty.RowsIn,
      Ty.RowsInList,Eff.RowsIn,Eff.empty,ScopeSignatures.scopeErrorTy, atErrorType]

private theorem write_admissible (nv : Nat) (Q : NoFailCtx) :
    PrimitiveAdmissible [] nv ScopeSignatures.writeTextIn Q [] [] := by
  constructor
  · rfl
  · simp [ScopeSignatures.writeTextIn, ScopeSignatures.ioIn]
  · simp
  · rfl
  · simp
  · simp [ScopeSignatures.writeTextIn, ScopeSignatures.ioIn, Eff.RowsIn, Ty.RowsInList]
  · simp [ScopeSignatures.writeTextIn, ScopeSignatures.ioIn, Qsig, QTys, QTy, QEff, Benitoite.Release.Qempty]
  · simp [ScopeSignatures.writeTextIn, ScopeSignatures.ioIn, Qsig, QTys, QTy, QEff, Benitoite.Release.Qempty,
      RowTransport]
  · simp [ScopeSignatures.writeTextIn,ScopeSignatures.ioIn,PrimSig.tel,signatureTel,Tel.RowsIn,Ty.RowsIn,
      Ty.RowsInList,Eff.RowsIn]

private theorem check_instance (Γ : Ctx) :
    SignatureInstance source.declarations.core [] Γ (Tel.instR [exactRange] ScopeSignatures.checkPathIn.tel)
      [] [] [] := by
  constructor
  · simp [ScopeSignatures.checkPathIn,ScopeSignatures.pureIn,PrimSig.tel,signatureTel,Tel.instR,Tel.substRAt,
      Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,
      Ty.WF,Ty.WFList,Tel.WF,Tel.norm,Ty.norm,Eff.norm,Eff.WF,Eff.Canonical,Eff.empty,
      RangeIx.inst,RangeIx.WF,atErrorType,ScopeSignatures.resultTy,ScopeSignatures.pathIn,ScopeSignatures.scopeErrorTy]
  · simp [TypeAnnotations]
  · exact ⟨rfl,by intro i a k h; cases i <;> cases h⟩
  · simp [RowAnnotations]
  · simp
  · rw [check_instantiated]
    have h := checkTy_annotation
    exact ⟨⟨by simp [Ty.WF], by simp [Ty.WF], (h Γ).wf, by simp [Eff.WF, Eff.empty, Ty.WFList, Eff.Canonical, Eff.norm]⟩,
      ⟨trivial, trivial, (h _).sorted, by simp [Eff.empty, sortedEff, sortedTys]⟩,
      ⟨trivial, trivial, (h _).declared, by simp [Eff.empty, declaredEff, declaredTys]⟩⟩

private theorem write_instance (Γ : Ctx) :
    SignatureInstance source.declarations.core [] Γ (Tel.instR [exactRange] ScopeSignatures.writeTextIn.tel)
      [] [] [] := by
  constructor
  · simp [ScopeSignatures.writeTextIn,ScopeSignatures.ioIn,PrimSig.tel,signatureTel,Tel.instR,Tel.substRAt,
      Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,
      Ty.WF,Ty.WFList,Tel.WF,Tel.norm,Ty.norm,Eff.norm,Eff.WF,Eff.Canonical,
      RangeIx.inst,RangeIx.WF]
  · simp [TypeAnnotations]
  · exact ⟨rfl,by intro i a k h; cases i <;> cases h⟩
  · simp [RowAnnotations]
  · simp
  · rw [write_instantiated]
    have h := writeResult_annotation
    exact ⟨⟨(pathTy_annotation Γ).wf, by simp [Ty.WF], (h Γ).wf,
        by simp [Eff.WF, narrowEff, Ty.WFList, Eff.Canonical, Eff.norm]⟩,
      ⟨trivial, trivial, (h _).sorted, by simp [narrowEff, sortedEff, sortedTys]⟩,
      ⟨trivial, trivial, (h _).declared, by simp [narrowEff, declaredEff, declaredTys]⟩⟩

private theorem check_head (Q : NoFailCtx) (Γ : Ctx) :
    CallHeadTy source.declarations table Q [] Γ (.primName "Scope.checkPathIn" [] [] [.fixed exactRange])
      checkTel [] := by
  have h := CallHeadTy.prim (D := source.declarations) (B := table) (Q := Q) (C := []) (Γ := Γ)
    (b := "Scope.checkPathIn") (s := ScopeSignatures.checkPathIn) (ts := []) (es := []) (rs := [exactRange])
    table_check check_ranges
    (by simp [ScopeSignatures.checkPathIn, ScopeSignatures.pureIn, NamesWF]) (check_admissible _ Q)
    (check_instance Γ)
  simpa only [List.map_cons, List.map_nil, check_instantiated] using h

private theorem write_head (Q : NoFailCtx) (Γ : Ctx) :
    CallHeadTy source.declarations table Q [] Γ (.primName "File.writeTextIn" [] [] [.fixed exactRange])
      writeTel [] := by
  have h := CallHeadTy.prim (D := source.declarations) (B := table) (Q := Q) (C := []) (Γ := Γ)
    (b := "File.writeTextIn") (s := ScopeSignatures.writeTextIn) (ts := []) (es := []) (rs := [exactRange])
    table_write write_ranges
    (by simp [ScopeSignatures.writeTextIn, ScopeSignatures.ioIn, NamesWF]) (write_admissible _ Q)
    (write_instance Γ)
  simpa only [List.map_cons, List.map_nil, write_instantiated] using h

/-! ## 呼出しの型付け -/

private theorem empty_sub (e : Eff) : Eff.Sub Eff.empty e :=
  ⟨by intro a ha; simp [Eff.empty,Eff.mem,Eff.test,Eff.atoms] at ha,
    by intro t ht; obtain ⟨u,hu,_⟩ := ht; simp [Eff.empty,Eff.fails] at hu⟩

@[simp] theorem mainEff_shiftV (k c : Nat) : Eff.shiftV k c mainEff = mainEff := by
  simp [Eff.shiftV, mainEff]

theorem mainEff_annotation (Γ : Ctx) : Ty.Annotation source.declarations.core [] Γ (.dependentFn (.done (.base .unit) mainEff)) :=
  ⟨by simp [mainEff,Ty.WF,Tel.WF,Ty.WFList,Eff.WF,Eff.Canonical,Eff.norm],
    by simp [mainEff,Ty.Sorted,Tel.Sorted,sortedEff,sortedTys],
    by simp [mainEff,Ty.Declared,Tel.Declared,declaredEff,declaredTys]⟩

/-- 検査の呼出しは結果型 `Result[PathIn["/data/a.txt"], Scope.ScopeError]` を持ち、純粋なので効果を宣言の効果へ
広げてよい。 -/
theorem check_typed (Q : NoFailCtx) (R : Option Ty) :
    HasTypeQ source.declarations table op Q [] [] [] [] R .other checkCall checkTy mainEff := by
  apply HasTypeQ.E_CallDirect (r := checkTy) (e := Eff.empty) (check_head Q [])
  · simp [CallOk, Tel.names, telBinders]
    exact List.Perm.refl _
  · exact .cons (.E_Sub (.E_Literal trivial) .refl (empty_sub _).covers ⟨trivial, trivial, trivial⟩)
      (.cons (.E_Sub (.E_Literal trivial) .refl (empty_sub _).covers ⟨trivial, trivial, trivial⟩) .nil)
  · simp [Tel.shiftV, bindParams, liftMany, boundVars, recordFields, fieldAt, Ty.shiftV,
      Eff.shiftV, Eff.empty, atErrorType, exactRange, Literal.toConst, Const.type, List.range, List.range.loop]
    apply ValsTel.param
    · exact ⟨by simp [Ty.WF], trivial, trivial⟩
    · exact .var rfl (by simp [Ordinary, Ty.core])
    · exact .refl
    · simp [Tel.bind, Tel.rawBind, Tel.argumentsEnv, Ty.rawBind, Eff.rawBind, valEnv,
        substAtoms_nil, instAtoms_nil, rowFails, Tel.norm, Ty.norm, Ty.normTys, Eff.norm, rawBindTys]
      apply ValsTel.param
      · exact ⟨by simp [Ty.WF], trivial, trivial⟩
      · exact .var rfl (by simp [Ordinary, Ty.core])
      · exact .refl
      · simp [Tel.bind, Tel.rawBind, Tel.argumentsEnv, Ty.rawBind, Eff.rawBind, valEnv,
          substAtoms_nil, instAtoms_nil, rowFails, Tel.norm, Ty.norm, Ty.normTys, Eff.norm, rawBindTys]
        exact .done (Ty.Annotation.done_empty (checkTy_annotation _))
  · simp [Ty.shiftV, atErrorType]
    exact .refl
  · exact (empty_sub _).covers
  · exact checkTy_annotation []

/-- 書き込みの呼出しの効果 `{File.Write["/data/a.txt"]}` を、それを覆う効果 ε で型付ける。 -/
theorem write_typed_in (ε : Eff) (hc : Eff.Covers [] [] (Eff.shiftV 2 0 ε) narrowEff)
    (Q : NoFailCtx) (Δ : BuilderCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty)
    (hΓ : Γ[0]? = some (some pathTy)) :
    HasTypeQ source.declarations table op Q Δ [] Γ Φ R .other writeCall writeResult ε := by
  apply HasTypeQ.E_CallDirect (r := writeResult) (e := narrowEff) (write_head Q Γ)
  · simp [CallOk, Tel.names, telBinders]
    exact List.Perm.refl _
  · exact .cons (.E_Sub (.E_Local hΓ (by simp [Ordinary, Ty.core])) .refl (empty_sub _).covers
      (pathTy_annotation Γ))
      (.cons (.E_Sub (.E_Literal trivial) .refl (empty_sub _).covers ⟨trivial, trivial, trivial⟩) .nil)
  · simp [Tel.shiftV, bindParams, liftMany, boundVars, recordFields, fieldAt, Ty.shiftV,
      Eff.shiftV, narrowEff, exactRange, List.range, List.range.loop, writeResult, Literal.toConst, Const.type]
    apply ValsTel.param
    · exact (pathTy_annotation _)
    · exact .var rfl (by simp [Ordinary, Ty.core])
    · exact .refl
    · simp [Tel.bind, Tel.rawBind, Tel.argumentsEnv, Ty.rawBind, Eff.rawBind, valEnv,
        substAtoms_nil, instAtoms_nil, rowFails, Tel.norm, Ty.norm, Ty.normTys, Eff.norm, rawBindTys]
      apply ValsTel.param
      · exact ⟨by simp [Ty.WF], trivial, trivial⟩
      · exact .var rfl (by simp [Ordinary, Ty.core])
      · exact .refl
      · simp [Tel.bind, Tel.rawBind, Tel.argumentsEnv, Ty.rawBind, Eff.rawBind, valEnv,
          substAtoms_nil, instAtoms_nil, rowFails, Tel.norm, Ty.norm, Ty.normTys, Eff.norm, rawBindTys]
        exact .done ⟨⟨(writeResult_annotation _).wf, by simp [Eff.WF, Ty.WFList, Eff.Canonical, Eff.norm]⟩,
          ⟨(writeResult_annotation _).sorted, by simp [sortedEff, sortedTys]⟩,
          ⟨(writeResult_annotation _).declared, by simp [declaredEff, declaredTys]⟩⟩
  · simp [writeResult, Ty.shiftV]
    exact .refl
  · exact hc
  · exact writeResult_annotation Γ

/-- 書き込みの呼出しを、宣言の効果 `{File.Write["/data/**"]}` へ被覆で広げる。 -/
theorem write_typed (Q : NoFailCtx) (Δ : BuilderCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty)
    (hΓ : Γ[0]? = some (some pathTy)) :
    HasTypeQ source.declarations table op Q Δ [] Γ Φ R .other writeCall writeResult mainEff :=
  write_typed_in mainEff (by simpa using mainEff_covers [] []) Q Δ Γ Φ R hΓ

@[simp] theorem narrowEff_shiftV (k c : Nat) : Eff.shiftV k c narrowEff = narrowEff := by
  simp [Eff.shiftV, narrowEff]

/-! ## 照合の腕 -/

/-- 標準の宣言の `Result.Ok`。 -/
private abbrev okDecl : ConDecl := ⟨"Result", 2, [.tvar 0]⟩

private theorem cons_ok : source.declarations.core.cons "Result.Ok" = some okDecl :=
  ((http_declarations positiveExternals).file ScopeDeclarations.result (by simp [ScopeDeclarations.file])).2
    ("Result.Ok", okDecl) (by simp [ScopeDeclarations.result, StandardKeyTyping.DataDecl.entries])

/-- 照合する値を束縛した腕の文脈。 -/
abbrev armCtx : Ctx := Ctx.extend [] checkTy

private theorem var0_data : (Term.var 0).HasSort armCtx .data := by
  simp [Term.HasSort, Term.References, Term.VarsIn, Ctx.Readable, Term.Shape, Ctx.extend, Ty.shiftV, Ordinary,
    Ty.core, Ty.HasSort, Ty.sort?]

/-- 照合する値は data の sort を持つので、観測は番号 0 の変数である。 -/
theorem armCtx_obs : scrutObs armCtx = some (.var 0) := by
  unfold scrutObs
  rw [ite_eq_left ⟨.data, var0_data⟩]

private theorem ok_test_wf :
    Pred.WellFormed source.declarations.core [] armCtx (.constructorIs (.var 0) "Result.Ok") := by
  refine ⟨by simp [Pred.WF, Pred.VarsIn, Term.VarsIn, Ctx.extend], var0_data, ?_⟩
  refine ⟨var0_data.1, "Result", [pathTy, atErrorType], okDecl, ?_, cons_ok, rfl⟩
  exact .var rfl (by simp [Ty.shiftV, Ty.norm, Ty.normTys, Ty.core, atErrorType, exactRange])

private theorem not_ok_test_wf :
    Pred.WellFormed source.declarations.core [] armCtx (.not (.constructorIs (.var 0) "Result.Ok")) :=
  ⟨ok_test_wf.wf, ok_test_wf.sorted, ok_test_wf.declared⟩

private theorem no_links_facts {Γ : Ctx} {n : Nat} {obs : Option Term} :
    FactsWF source.declarations.core [] Γ (fieldFacts n obs []) := by
  cases obs <;> simp [FactsWF, fieldFacts]

theorem okAlt_ty :
    AltsTy source.declarations.core (Alternative.toCoreList okAlt) (checkTy.shiftV 1 0) [pathTy] := by
  refine ⟨by simp [okAlt, Alternative.toCoreList], rfl, ?_, ?_⟩
  · intro alt h
    simp [okAlt, Alternative.toCoreList, Alternative.toCore] at h; subst h; rfl
  · intro alt h
    simp [okAlt, Alternative.toCoreList, Alternative.toCore] at h; subst h
    refine ⟨[pathTy], ?_, List.Perm.refl _, rfl⟩
    have hs : substTypeAt 0 [pathTy, atErrorType] [] (.tvar 0) = pathTy := by
      simp [substTypeAt, Ty.bind, Ty.rawBind, typeEnvAt, Ty.norm, exactRange]
    have hp := PatTy.P_Con (P := source.declarations.core) (ps := [.var]) (ts := [pathTy, atErrorType])
      (δ := [pathTy] ++ []) cons_ok rfl (by simp [Ty.WF])
      (by simpa [okDecl, Ty.subst, Ty.substAt, hs] using
        (PatTys.cons (P := source.declarations.core) (PatTy.P_Var (a := pathTy)) .nil))
    simpa [Pattern.toCore, Pattern.toCoreList, Ty.shiftV, atErrorType] using hp

/-- 標準の宣言の `Result.Error`。 -/
private abbrev errDecl : ConDecl := ⟨"Result", 2, [.tvar 1]⟩

private theorem cons_err : source.declarations.core.cons "Result.Error" = some errDecl :=
  ((http_declarations positiveExternals).file ScopeDeclarations.result (by simp [ScopeDeclarations.file])).2
    ("Result.Error", errDecl) (by simp [ScopeDeclarations.result, StandardKeyTyping.DataDecl.entries])

private theorem err_test_wf :
    Pred.WellFormed source.declarations.core [] armCtx (.constructorIs (.var 0) "Result.Error") := by
  refine ⟨by simp [Pred.WF, Pred.VarsIn, Term.VarsIn, Ctx.extend], var0_data, ?_⟩
  refine ⟨var0_data.1, "Result", [pathTy, atErrorType], errDecl, ?_, cons_err, rfl⟩
  exact .var rfl (by simp [Ty.shiftV, Ty.norm, Ty.normTys, Ty.core, atErrorType, exactRange])

private theorem not_err_test_wf :
    Pred.WellFormed source.declarations.core [] armCtx (.not (.constructorIs (.var 0) "Result.Error")) :=
  ⟨err_test_wf.wf, err_test_wf.sorted, err_test_wf.declared⟩

theorem errAlt_ty :
    AltsTy source.declarations.core (Alternative.toCoreList errAlt) (checkTy.shiftV 1 0) [atErrorType] := by
  refine ⟨by simp [errAlt, Alternative.toCoreList], rfl, ?_, ?_⟩
  · intro alt h
    simp [errAlt, Alternative.toCoreList, Alternative.toCore] at h; subst h; rfl
  · intro alt h
    simp [errAlt, Alternative.toCoreList, Alternative.toCore] at h; subst h
    refine ⟨[atErrorType], ?_, List.Perm.refl _, rfl⟩
    have hs : substTypeAt 0 [pathTy, atErrorType] [] (.tvar 1) = atErrorType := by
      simp [substTypeAt, Ty.bind, Ty.rawBind, typeEnvAt, Ty.norm, Ty.normTys, atErrorType]
    have hp := PatTy.P_Con (P := source.declarations.core) (ps := [.var]) (ts := [pathTy, atErrorType])
      (δ := [atErrorType] ++ []) cons_err rfl (by simp [Ty.WF])
      (by simpa [errDecl, Ty.subst, Ty.substAt, hs] using
        (PatTys.cons (P := source.declarations.core) (PatTy.P_Var (a := atErrorType)) .nil))
    simpa [Pattern.toCore, Pattern.toCoreList, Ty.shiftV, atErrorType] using hp

/-! ## 標準の宣言の Result の構成子 -/

theorem nodup_map_inj {α β : Type} {f : α → β} : ∀ {l : List α}, (l.map f).Nodup → ∀ {x y}, x ∈ l → y ∈ l →
    f x = f y → x = y
  | [], _, _, _, hx, _, _ => by cases hx
  | a :: l, h, x, y, hx, hy, he => by
    rw [List.map_cons, List.nodup_cons] at h
    rcases List.mem_cons.mp hx with rfl | hx' <;> rcases List.mem_cons.mp hy with rfl | hy'
    · rfl
    · exact absurd (he ▸ List.mem_map_of_mem hy') h.1
    · exact absurd (he.symm ▸ List.mem_map_of_mem hx') h.1
    · exact nodup_map_inj h.2 hx' hy' he

/-- 標準の宣言の一覧は Result の宣言を含む。 -/
theorem result_mem : ScopeDeclarations.result ∈ StandardModel.declarations := by
  simp only [StandardModel.declarations, StandardModel.baseDeclarations, List.mem_append, List.mem_filter]
  refine .inl (.inl (.inl (.inl (.inr ⟨?_, ?_⟩))))
  · simp [ScopeDeclarations.base, ScopeDeclarations.file]
  · decide

/-- 標準の宣言の表で Result に属する構成子は `Result.Ok` と `Result.Error` だけである。宣言の名前の重複のなさ
（`StandardModel.table` の欄）から、該当の行は Result の宣言の行に決まる。 -/
theorem result_ctor {externals c cd} (h : (StandardModel.program externals).cons c = some cd)
    (hd : cd.data = "Result") : c = "Result.Ok" ∨ c = "Result.Error" := by
  have hm := StandardModel.cons_mem h
  obtain ⟨d, hdm, he⟩ := List.mem_flatMap.mp hm
  obtain ⟨⟨c', args⟩, hc', heq⟩ := List.mem_map.mp he
  simp only [Prod.mk.injEq] at heq
  obtain ⟨rfl, rfl⟩ := heq
  have hname : d.name = ScopeDeclarations.result.name := hd
  have := nodup_map_inj (StandardModel.table externals).dataNames hdm result_mem hname
  subst this
  simp [ScopeDeclarations.result] at hc'
  rcases hc' with ⟨rfl, -⟩ | ⟨rfl, -⟩ <;> simp

/-- data ごとの構成子の一覧。Result は二つ、ほかは全構成子の名前である。 -/
def ctors : DataName → List ConName := fun d =>
  if d = "Result" then ["Result.Ok", "Result.Error"] else StandardModel.constructorNames

theorem ctors_complete : CtorsComplete source.declarations.core ctors := by
  intro c cd h
  by_cases hd : cd.data = "Result"
  · simp only [ctors, hd, ite_true]
    rcases result_ctor (externals := positiveExternals) h hd with rfl | rfl <;> simp
  · simp only [ctors, hd, ite_false]
    exact List.mem_map.mpr ⟨(c, cd), StandardModel.cons_mem (externals := positiveExternals) h, rfl⟩

/-- 二つの腕 `Result.Ok(p)`・`Result.Error(e)` は、既定の閉じた view で照合する値の型を網羅する。 -/
theorem arms_exhaustive :
    ViewExhaustive source.declarations source.declarations.view checkTy arms.unguardedPatterns := by
  apply CheckPatterns.exhaustiveWithView_view ctors_complete
  with_unfolding_all rfl

/-! ## 利用者の関数の呼出し -/

private abbrev gTel : Tel := .param "path" pathTy (.done (.base .unit) narrowEff)

private theorem gDef_tel : gDef.toFunDecl.tel = gTel := rfl
private theorem hDef_tel : hDef.toFunDecl.tel = .param "path" pathTy (.done (.base .unit) mainEff) := rfl

private theorem g_lookup : source.declarations.funs "g" = some gDef.toFunDecl := rfl

private theorem g_instantiated : instantiatedTel (rangeTel [] gDef.toFunDecl.tel) [] [] = gTel := by
  simp [rangeTel, gDef_tel, instantiatedTel, Tel.bind, Tel.rawBind, Ty.rawBind, Eff.rawBind, typeEnvAt,
    substAtoms_nil, instAtoms_nil, rowFails, Tel.norm, Ty.norm, Ty.normTys, Eff.norm, narrowEff, exactRange]

theorem narrow_annotation (Γ : Ctx) :
    Ty.Annotation source.declarations.core [] Γ (.dependentFn (.done (.base .unit) narrowEff)) :=
  ⟨by simp [narrowEff,Ty.WF,Tel.WF,Ty.WFList,Eff.WF,Eff.Canonical,Eff.norm],
    by simp [narrowEff,Ty.Sorted,Tel.Sorted,sortedEff,sortedTys],
    by simp [narrowEff,Ty.Declared,Tel.Declared,declaredEff,declaredTys]⟩

private theorem g_head (Q : NoFailCtx) (Γ : Ctx) :
    CallHeadTy source.declarations table Q [] Γ (.funName "g" [] [] []) gTel [] := by
  have hadm : Admissible table [] Γ.length (TypeCtx.constraints gDef.toFunDecl.tparams) gDef.toFunDecl.neffs
      (Qsig gDef.toFunDecl.coreParams gDef.toFunDecl.ret gDef.toFunDecl.eff) Q [] [] gDef.toFunDecl.eff := by
    refine ⟨⟨rfl, ?_⟩, ?_, rfl, ?_, ?_, ?_, ?_⟩
    · intro i a param hi; cases hi
    · intro a h; cases h
    · intro e h; cases h
    · simp [gDef, narrowEff, Eff.RowsIn, Ty.RowsInList]
    · intro i hi
      simp [gDef, Examples.mainDef, FunDecl.coreParams, FunDecl.dictTys, Qsig, QTys, QTy, QEff, narrowEff,
        exactRange, Benitoite.Release.Qempty] at hi
    · intro i hi
      simp [gDef, Examples.mainDef, FunDecl.coreParams, FunDecl.dictTys, Qsig, QTys, QTy, QEff, narrowEff,
        exactRange, Benitoite.Release.Qempty] at hi
  have hsig : SignatureInstance source.declarations.core [] Γ (rangeTel [] gDef.toFunDecl.tel)
      (TypeCtx.kinds gDef.toFunDecl.tparams) [] [] := by
    constructor
    · simp [rangeTel, gDef_tel, Ty.WF, Tel.WF, Ty.WFList, RangeIx.WF, narrowEff, Eff.WF, Eff.Canonical, Eff.norm]
    · simp [TypeAnnotations]
    · exact ⟨rfl, by intro i a k h; cases i <;> cases h⟩
    · simp [RowAnnotations]
    · simp
    · rw [g_instantiated]
      have hn := narrow_annotation (Γ.extend pathTy)
      exact ⟨⟨(pathTy_annotation Γ).wf, hn.wf⟩, ⟨trivial, hn.sorted⟩, ⟨trivial, hn.declared⟩⟩
  have h := CallHeadTy.fn (D := source.declarations) (B := table) (Q := Q) (C := []) (Γ := Γ)
    (f := "g") (fd := gDef.toFunDecl) (ts := []) (es := []) (rs := []) g_lookup rfl
    (by simp [gDef, Examples.mainDef, FunDecl.coreNames, FunDecl.coreParams, FunDecl.dictTys, internalNames, NamesWF])
    ⟨rfl, by simp, by simp⟩ hadm hsig
  simpa only [List.map_nil, g_instantiated] using h

/-- h の本体の `g(path: path)`。効果 `{File.Write["/data/a.txt"]}` を h の宣言の効果へ被覆で広げる。 -/
theorem callG_typed (Q : NoFailCtx) (Δ : BuilderCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty)
    (hΓ : Γ[0]? = some (some pathTy)) :
    HasTypeQ source.declarations table op Q Δ [] Γ Φ R .other callG (.base .unit) mainEff := by
  apply HasTypeQ.E_CallDirect (r := .base .unit) (e := narrowEff) (g_head Q Γ)
  · simp [CallOk, Tel.names, telBinders]
  · exact .cons (.E_Sub (.E_Local hΓ (by simp [Ordinary, Ty.core])) .refl (empty_sub _).covers
      (pathTy_annotation Γ)) .nil
  · simp [Tel.shiftV, bindParams, liftMany, boundVars, recordFields, fieldAt, Ty.shiftV,
      Eff.shiftV, narrowEff, exactRange, List.range, List.range.loop]
    apply ValsTel.param
    · exact (pathTy_annotation _)
    · exact .var rfl (by simp [Ordinary, Ty.core])
    · exact .refl
    · simp [Tel.bind, Tel.rawBind, Tel.argumentsEnv, Ty.rawBind, Eff.rawBind, valEnv,
        substAtoms_nil, instAtoms_nil, rowFails, Tel.norm, Ty.norm, Ty.normTys, Eff.norm, rawBindTys]
      exact .done (narrow_annotation _)
  · simp [Ty.shiftV]
    exact .refl
  · simp only [mainEff_shiftV]
    exact mainEff_covers _ _
  · exact ⟨trivial, trivial, trivial⟩

private abbrev fTel : Tel := .param "path" pathTy (.done (.base .unit) mainEff)

private theorem fDef_tel : fDef.toFunDecl.tel = fTel := rfl

private theorem f_lookup : source.declarations.funs "f" = some fDef.toFunDecl := rfl

private theorem f_instantiated : instantiatedTel (rangeTel [] fDef.toFunDecl.tel) [] [] = fTel := by
  simp [rangeTel, fDef_tel, instantiatedTel, Tel.bind, Tel.rawBind, Ty.rawBind, Eff.rawBind, typeEnvAt,
    substAtoms_nil, instAtoms_nil, rowFails, Tel.norm, Ty.norm, Ty.normTys, Eff.norm, mainEff, dataRange,
    TargetStepExamples.dataRange]

private theorem main_annotation (Γ : Ctx) :
    Ty.Annotation source.declarations.core [] Γ (.dependentFn (.done (.base .unit) mainEff)) := mainEff_annotation Γ

private theorem f_head (Q : NoFailCtx) (Γ : Ctx) :
    CallHeadTy source.declarations table Q [] Γ (.funName "f" [] [] []) fTel [] := by
  have hadm : Admissible table [] Γ.length (TypeCtx.constraints fDef.toFunDecl.tparams) fDef.toFunDecl.neffs
      (Qsig fDef.toFunDecl.coreParams fDef.toFunDecl.ret fDef.toFunDecl.eff) Q [] [] fDef.toFunDecl.eff := by
    refine ⟨⟨rfl, ?_⟩, ?_, rfl, ?_, ?_, ?_, ?_⟩
    · intro i a param hi; cases hi
    · intro a h; cases h
    · intro e h; cases h
    · simp [fDef, mainEff, Eff.RowsIn, Ty.RowsInList]
    · intro i hi
      simp [fDef, Examples.mainDef, FunDecl.coreParams, FunDecl.dictTys, Qsig, QTys, QTy, QEff, mainEff,
        Benitoite.Release.Qempty] at hi
    · intro i hi
      simp [fDef, Examples.mainDef, FunDecl.coreParams, FunDecl.dictTys, Qsig, QTys, QTy, QEff, mainEff,
        Benitoite.Release.Qempty] at hi
  have hsig : SignatureInstance source.declarations.core [] Γ (rangeTel [] fDef.toFunDecl.tel)
      (TypeCtx.kinds fDef.toFunDecl.tparams) [] [] := by
    constructor
    · simp [rangeTel, fDef_tel, Ty.WF, Tel.WF, Ty.WFList, RangeIx.WF, mainEff, Eff.WF, Eff.Canonical, Eff.norm]
    · simp [TypeAnnotations]
    · exact ⟨rfl, by intro i a k h; cases i <;> cases h⟩
    · simp [RowAnnotations]
    · simp
    · rw [f_instantiated]
      have hn := main_annotation (Γ.extend pathTy)
      exact ⟨⟨(pathTy_annotation Γ).wf, hn.wf⟩, ⟨trivial, hn.sorted⟩, ⟨trivial, hn.declared⟩⟩
  have h := CallHeadTy.fn (D := source.declarations) (B := table) (Q := Q) (C := []) (Γ := Γ)
    (f := "f") (fd := fDef.toFunDecl) (ts := []) (es := []) (rs := []) f_lookup rfl
    (by simp [fDef, Examples.mainDef, FunDecl.coreNames, FunDecl.coreParams, FunDecl.dictTys, internalNames, NamesWF])
    ⟨rfl, by simp, by simp⟩ hadm hsig
  simpa only [List.map_nil, f_instantiated] using h

/-- main の腕の `f(path: p)`。効果は f の宣言の効果である。 -/
theorem callF_typed (Q : NoFailCtx) (Δ : BuilderCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (p : Position)
    (hΓ : Γ[0]? = some (some pathTy)) :
    HasTypeQ source.declarations table op Q Δ [] Γ Φ R p callF (.base .unit) mainEff := by
  apply HasTypeQ.E_CallDirect (r := .base .unit) (e := mainEff) (f_head Q Γ)
  · simp [CallOk, Tel.names, telBinders]
  · exact .cons (.E_Sub (.E_Local hΓ (by simp [Ordinary, Ty.core])) .refl (empty_sub _).covers
      (pathTy_annotation Γ)) .nil
  · simp [Tel.shiftV, bindParams, liftMany, boundVars, recordFields, fieldAt, Ty.shiftV,
      Eff.shiftV, mainEff, exactRange, List.range, List.range.loop]
    apply ValsTel.param
    · exact (pathTy_annotation _)
    · exact .var rfl (by simp [Ordinary, Ty.core])
    · exact .refl
    · simp [Tel.bind, Tel.rawBind, Tel.argumentsEnv, Ty.rawBind, Eff.rawBind, valEnv,
        substAtoms_nil, instAtoms_nil, rowFails, Tel.norm, Ty.norm, Ty.normTys, Eff.norm, rawBindTys]
      exact .done (main_annotation _)
  · simp [Ty.shiftV]
    exact .refl
  · simp only [mainEff_shiftV]
    exact Eff.Covers.refl _ _ _
  · exact ⟨trivial, trivial, trivial⟩


/-- 二つの腕の型付け。`Result.Ok(p)` の腕は束縛した p を f へ渡し、`Result.Error(e)` の腕は何もしない。 -/
theorem arms_typed (Q : NoFailCtx) (R : Option Ty) (p : Position) :
    HasArmsQ source.declarations table op Q (localExtend 1 []) [] armCtx [] (R.map (Ty.shiftV 1 0)) p arms
      (checkTy.shiftV 1 0) ((Ty.base .unit).shiftV 1 0) (Eff.shiftV 1 0 mainEff) := by
  apply HasArmsQ.plain (δ := [pathTy]) (links := [])
  · simp [Alternative.Valid, okAlt, Pattern.Valid, Pattern.ValidList]
  · exact okAlt_ty
  · intro link h; cases h
  · exact no_links_facts
  · rw [armCtx_obs]
    intro q hq
    simp [pathFacts, matchedTests, excludedTests, okAlt, Alternative.toCoreList, Alternative.toCore,
      Pattern.toCore, Pattern.toCoreList, patternTest?, excludedTest?, irrefutableField, PathTest.predicate] at hq
    rcases hq with rfl | rfl
    · exact ok_test_wf
    · exact not_ok_test_wf
  · simp only [mainEff_shiftV, Ty.shiftV]
    exact .B_Last (callF_typed Q _ _ _ _ _ (by simp [bindParams, Ty.shiftV, exactRange]))
  · apply HasArmsQ.plain (δ := [atErrorType]) (links := [])
    · simp [Alternative.Valid, errAlt, Pattern.Valid, Pattern.ValidList]
    · exact errAlt_ty
    · intro link h; cases h
    · exact no_links_facts
    · rw [armCtx_obs]
      intro q hq
      simp [pathFacts, matchedTests, excludedTests, errAlt, Alternative.toCoreList, Alternative.toCore,
        Pattern.toCore, Pattern.toCoreList, patternTest?, excludedTest?, irrefutableField, PathTest.predicate] at hq
      rcases hq with rfl | rfl
      · exact err_test_wf
      · exact not_err_test_wf
    · simp only [mainEff_shiftV, Ty.shiftV]
      exact .B_Last (.E_Sub .E_Unit .refl (empty_sub _).covers ⟨trivial, trivial, trivial⟩)
    · exact .nil

/-- main の本体の型付け。検査の呼出しの結果を照合し、本体の効果は宣言の効果に等しい。 -/
theorem body_typed (Q : NoFailCtx) (R : Option Ty) (p : Position) :
    HasBlockQ source.declarations table op Q [] [] [] [] R p mainDef.body (.base .unit) mainEff :=
  .B_Last (.E_Match (by simp [arms]) (by simp [Ordinary, Ty.core]) (check_typed Q R) (arms_typed Q R p)
    arms_exhaustive (checkTy_annotation []) ⟨trivial, trivial, trivial⟩)

/-! ## プログラム -/

private theorem mainDef_tel : mainDef.toFunDecl.tel = .done (.base .unit) mainEff := rfl

theorem defTable_cases {f d} (h : defTable f = some d) :
    (f = "main" ∧ d = mainDef) ∨ (f = "f" ∧ d = fDef) ∨ (f = "g" ∧ d = gDef) ∨ (f = "h" ∧ d = hDef) := by
  simp only [defTable] at h
  split at h
  · cases h; exact .inl ⟨‹_›, rfl⟩
  · split at h
    · cases h; exact .inr (.inl ⟨‹_›, rfl⟩)
    · split at h
      · cases h; exact .inr (.inr (.inl ⟨‹_›, rfl⟩))
      · split at h
        · cases h; exact .inr (.inr (.inr ⟨‹_›, rfl⟩))
        · cases h

private theorem param_annotation {ε : Eff}
    (hε : ∀ Γ, Ty.Annotation source.declarations.core [] Γ (.dependentFn (.done (.base .unit) ε))) (Γ : Ctx) :
    Ty.Annotation source.declarations.core [] Γ (.dependentFn (.param "path" pathTy (.done (.base .unit) ε))) :=
  ⟨⟨(pathTy_annotation Γ).wf, by simpa [Ctx.extend, Ty.WF] using (hε (Γ.extend pathTy)).wf⟩,
    ⟨trivial, (hε (Γ.extend pathTy)).sorted⟩, ⟨trivial, (hε (Γ.extend pathTy)).declared⟩⟩

private theorem write_body_scoped (ne : Nat) :
    Block.Scoped 0 ne 1 0 (.lastDiscard writeCall) := by
  simp [writeCall, Block.Scoped, Expr.Scoped, Exprs.Scoped, scopedTypes, scopedRows, RangeIx.WF]
  decide

/-- 表層の整形式。型の宣言は標準の宣言の整形式を引き継ぐ。 -/
theorem wellFormed : source.WellFormed where
  types := (MainExamples.wellFormed positiveExternals positive_wf).types
  defs := by
    intro f d hd
    rcases defTable_cases hd with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩
    · refine ⟨by simp [mainDef,Examples.mainDef,FunDecl.coreNames,FunDecl.coreParams,FunDecl.dictTys,internalNames,NamesWF],?_,
        ?_⟩
      · change SignatureScopedR _ [] [] 0 (.done (.base .unit) mainEff)
        refine ⟨⟨(mainEff_annotation []).wf,?_,?_⟩,?_,?_,(mainEff_annotation []).range_empty⟩
        all_goals simp [mainEff,Ty.RowsIn,Tel.RowsIn,Eff.RowsIn,Ty.RowsInList,Ty.RangesScoped,
          Tel.RangesScoped,Eff.RangesScoped,rangesScopedTypes,Ty.HasKind,kindsTel,kindsEff,kindsList,RangeIx.WF]
      · simp [mainDef,Examples.mainDef,checkCall,callF,arms,okAlt,errAlt,Block.Scoped,Expr.Scoped,Exprs.Scoped,
          Arms.Scoped,scopedTypes,scopedRows,FunDecl.coreParams,Arm.bindersOf,Alternative.toCoreList,
          Alternative.toCore,Pattern.toCore,Pattern.toCoreList,Pat.binders,Pat.bindersList,RangeIx.WF]
        decide
    · refine ⟨by simp [fDef,Examples.mainDef,FunDecl.coreNames,FunDecl.coreParams,FunDecl.dictTys,internalNames,NamesWF],?_,
        ?_⟩
      · change SignatureScopedR _ [] [] 0 (.param "path" pathTy (.done (.base .unit) mainEff))
        have ha := param_annotation mainEff_annotation []
        refine ⟨⟨ha.wf,?_,?_⟩,?_,?_,ha.range_empty⟩
        all_goals simp [mainEff,Ty.RowsIn,Tel.RowsIn,Eff.RowsIn,Ty.RowsInList,Ty.RangesScoped,
          Tel.RangesScoped,Eff.RangesScoped,rangesScopedTypes,Ty.HasKind,kindsTel,kindsEff,kindsList,RangeIx.WF]
      · exact write_body_scoped _
    · refine ⟨by simp [gDef,Examples.mainDef,FunDecl.coreNames,FunDecl.coreParams,FunDecl.dictTys,internalNames,NamesWF],?_,
        ?_⟩
      · change SignatureScopedR _ [] [] 0 (.param "path" pathTy (.done (.base .unit) narrowEff))
        have ha := param_annotation narrow_annotation []
        refine ⟨⟨ha.wf,?_,?_⟩,?_,?_,ha.range_empty⟩
        all_goals simp [narrowEff,Ty.RowsIn,Tel.RowsIn,Eff.RowsIn,Ty.RowsInList,Ty.RangesScoped,
          Tel.RangesScoped,Eff.RangesScoped,rangesScopedTypes,Ty.HasKind,kindsTel,kindsEff,kindsList,RangeIx.WF]
      · exact write_body_scoped _
    · refine ⟨by simp [hDef,Examples.mainDef,FunDecl.coreNames,FunDecl.coreParams,FunDecl.dictTys,internalNames,NamesWF],?_,
        ?_⟩
      · change SignatureScopedR _ [] [] 0 (.param "path" pathTy (.done (.base .unit) mainEff))
        have ha := param_annotation mainEff_annotation []
        refine ⟨⟨ha.wf,?_,?_⟩,?_,?_,ha.range_empty⟩
        all_goals simp [mainEff,Ty.RowsIn,Tel.RowsIn,Eff.RowsIn,Ty.RowsInList,Ty.RangesScoped,
          Tel.RangesScoped,Eff.RangesScoped,rangesScopedTypes,Ty.HasKind,kindsTel,kindsEff,kindsList,RangeIx.WF]
      · simp [hDef,Examples.mainDef,callG,Block.Scoped,Expr.Scoped,Exprs.Scoped,scopedTypes,scopedRows,
          FunDecl.coreParams]
  impls := by intro i id hi; cases hi
  accessors := by intro f c k h; cases h
  testers := by intro f c h; cases h

/-- 表層の型付け。main の本体は検査の呼出しの結果を照合して f を呼び、f の本体は書き込みの効果を被覆で広げ、
g の本体の効果は宣言の効果に等しく、h の本体は g の狭い効果を被覆で広げる。 -/
theorem wellTyped : source.WellTyped table op where
  variance := (variance_valid positiveExternals).sameTypes ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩
  defs := by
    intro f d hd
    rcases defTable_cases hd with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩
    · refine ⟨by simp [mainDef, Examples.mainDef, FunDecl.coreNames, FunDecl.coreParams, FunDecl.dictTys,
          internalNames, NamesWF], ?_, by rw [mainDef_tel]; exact (mainEff_annotation []).range_empty, ?_⟩
      · rw [mainDef_tel]; simp [Ty.HasKind, kindsTel, kindsEff, kindsList, mainEff]
      · rw [mainDef_tel]; exact .done (body_typed _ _ _)
    · refine ⟨by simp [fDef, Examples.mainDef, FunDecl.coreNames, FunDecl.coreParams, FunDecl.dictTys,
          internalNames, NamesWF], ?_, ?_, ?_⟩
      · rw [fDef_tel]; simp [Ty.HasKind, kindsTel, kindsEff, kindsList, mainEff]
      · rw [fDef_tel]; exact (param_annotation mainEff_annotation []).range_empty
      · rw [fDef_tel]
        exact .param (.done (.B_LastDiscard (write_typed _ _ _ _ _ (by simp [Ctx.extend, Ty.shiftV]))))
    · refine ⟨by simp [gDef, Examples.mainDef, FunDecl.coreNames, FunDecl.coreParams, FunDecl.dictTys,
          internalNames, NamesWF], ?_, ?_, ?_⟩
      · rw [gDef_tel]; simp [Ty.HasKind, kindsTel, kindsEff, kindsList, narrowEff]
      · rw [gDef_tel]; exact (param_annotation narrow_annotation []).range_empty
      · rw [gDef_tel]
        exact .param (.done (.B_LastDiscard (write_typed_in narrowEff (by simpa using Eff.Covers.refl [] [] narrowEff)
          _ _ _ _ _ (by simp [Ctx.extend, Ty.shiftV]))))
    · refine ⟨by simp [hDef, Examples.mainDef, FunDecl.coreNames, FunDecl.coreParams, FunDecl.dictTys,
          internalNames, NamesWF], ?_, ?_, ?_⟩
      · rw [hDef_tel]; simp [Ty.HasKind, kindsTel, kindsEff, kindsList, mainEff]
      · rw [hDef_tel]; exact (param_annotation mainEff_annotation []).range_empty
      · rw [hDef_tel]
        exact .param (.done (.B_LastDiscard (callG_typed _ _ _ _ _ (by simp [Ctx.extend, Ty.shiftV]))))
  impls := by intro i id hi; cases hi
  effects := ⟨fun _ _ _ h => by simp [Program.declarationsFor, Program.declarations, Declarations.core, source,
      MainExamples.source, Examples.mainProgram] at h,
    fun _ _ h => by simp [Program.declarationsFor, Program.declarations, Declarations.core, source,
      MainExamples.source, Examples.mainProgram] at h,
    fun _ _ h => by simp [Program.declarationsFor, Program.declarations, Declarations.core, source,
      MainExamples.source, Examples.mainProgram] at h⟩

/-- 範囲付きのモデルが読む Result と Scope.ScopeError の宣言。 -/
theorem hasFile : ScopeDeclarations.HasFile core := (http_declarations positiveExternals).file

/-- main の宣言の形。 -/
theorem hasMain : source.HasMain mainEff := ⟨mainDef, rfl, rfl, rfl, rfl, rfl, rfl, Or.inl rfl, rfl⟩

/-- 対象の環境。 -/
abbrev σ0 : PathEnv := TargetReachExamples.environment

/-- 環境の束縛。 -/
theorem ready : σ0.Ready core table (.run mainClosure [] Store.empty) := by
  refine ⟨by simp [PathEnv.Valid,TargetReachExamples.environment,Scope.Domain.PathWordWF], ?_⟩
  intro r _
  cases r with
  | base b => cases b <;> exact ⟨[],rfl⟩
  | secrets => rfl

/-! ## 開始状態から書き込みの事象への到達 -/

/-- `/data/a.txt`。 -/
abbrev dataTarget : Target := TargetStepExamples.dataTarget

/-- 検査の成功値 `Result.Ok(checked(/data/a.txt))`。 -/
def okValue : Refinement.Val := ScopeDelta.resultValue true pathTy atErrorType (.checked dataTarget)

/-- 検査の δ は、`/data/a.txt` を `/data/**` と範囲 `/data/a.txt` の両方に属すると判定して成功値を返す。 -/
theorem check_delta :
    table.delta "Scope.checkPathIn" [] [] [exactRange]
      [.const (.string "/data/**"), .const (.string "/data/a.txt")] = some (.val okValue) := by
  have hp : ScopeDelta.parsePattern "/data/**" = some (.tree ["data"]) := by decide +kernel
  have ht : parseAtInput .path (.const (.string "/data/a.txt")) = some (.absolute (.path ["data", "a.txt"])) := by
    decide +kernel
  have hw : PathPattern.WF (.tree ["data"]) := by decide
  have hv : Scope.Domain.PathWordWF ["data", "a.txt"] := by decide
  have hm : (PathPattern.tree ["data"]).Matches ["data", "a.txt"] := by decide
  have hk : Range.MemK .path (.path (.exact ["data", "a.txt"])) (.path ["data", "a.txt"]) := by decide
  simp [table, ExternalModels.targets, ExternalModel.builtins, ModelTargets.builtins, ScopeSignatures.builtins,
    ScopeResponse.delta, ScopeDelta.delta, ScopeDelta.run, hp, ht, Checked.Scope.makePath, hw, hv, hm, exactRange, hk,
    ScopeDelta.ok, okValue]
  rfl

/-- 開始状態から、main の呼出し・検査の呼出しの二つの実引数の束縛・検査の δ・照合の `Result.Ok` の腕の選択・書き込みの
実引数の束縛を経て、観測 `/data/a.txt` を持つ書き込みの事象を伴う遷移へ進む（書き込みの失敗の応答）。 -/
theorem main_reach :
    ∃ s s', Steps core table σ0 (.run mainClosure [] Store.empty) [] s ∧
      Step core table σ0 s
        (some (.io "File.writeTextIn" [.checked dataTarget, .const (.string "x")] (.err "IO") [dataTarget])) s' := by
  exact ⟨_, _, .cons (.E_Fun (rs := []) rfl rfl rfl rfl rfl) (.cons (.E_Let rfl) (.cons (.E_Let rfl)
    (.cons (.E_Return rfl) (.cons (.E_Let rfl) (.cons (.E_Return rfl)
    (.cons (.E_Prim (rs := [exactRange]) rfl rfl rfl check_delta) (.cons (.E_Return rfl) (.cons (.E_Match rfl)
    (.cons (.E_MatchBody rfl rfl) (.cons (.E_Let rfl) (.cons (.E_Return rfl)
    (.cons (.E_Fun (rs := []) rfl rfl rfl rfl rfl) (.cons (.E_Let rfl) (.cons (.E_Let rfl) (.cons (.E_Return rfl)
    (.cons (.E_Let rfl) (.cons (.E_Return rfl) .nil))))))))))))))))),
    .E_IOErr (rs := [exactRange]) rfl rfl (Or.inl rfl) (by simp [NoHandler, markPush])
      (Or.inl ⟨.writeText, by decide, rfl, ⟨.writeText, rfl, rfl, rfl, .err "IO", dataTarget, rfl, rfl, rfl,
        by intro h; cases h⟩⟩)⟩

/-! ## 表層の対象健全性の適用 -/

/-- 表層の対象健全性が、被覆でだけ型付く main を持つプログラムに当たる。開始状態から到達したどの IO の事象の観測も、
事象の操作の名前の main の宣言した効果の原子が許す。 -/
theorem program_target_sound {evs : List Event} {s s' : State} {b : PrimName} {ws : List Refinement.Val}
    {o : Outcome} {obs : List Target}
    (hsteps : Steps core table σ0 (.run mainClosure [] Store.empty) evs s)
    (hst : Step core table σ0 s (some (.io b ws o obs)) s') :
    ∃ e l, table.sig b = some e ∧ e.opEff = some l ∧ ∀ t ∈ obs, Eff.Allows σ0 table.effKind mainEff l t :=
  surface_target_sound wellFormed wellTyped (ExternalModels.targets_core core hasFile)
    (ExternalModels.targets_scope core hasFile).toTargetAgreement hasMain ready _ _ _ _ _ _ _ hsteps hst

/-- 到達した書き込みの事象の観測 `/data/a.txt` は、main の宣言した効果が許す（前提が空疎でないこと）。 -/
theorem main_reach_allowed : Eff.Allows σ0 table.effKind mainEff "File.Write" dataTarget := by
  obtain ⟨s, s', hs, hst⟩ := main_reach
  obtain ⟨e, l, hsig, hop, hall⟩ := program_target_sound hs hst
  rw [table_write] at hsig
  cases hsig
  simp [ScopeSignatures.writeTextIn, ScopeSignatures.ioIn] at hop
  subst hop
  exact hall dataTarget (List.mem_singleton_self _)

/-- `/etc/passwd`。 -/
abbrev passwd : Target := TargetStepExamples.passwd

/-- main の宣言した効果は、どの操作の名前でも `/etc/passwd` を許さない。 -/
theorem passwd_not_allowed (l : EffName) : ¬ Eff.Allows σ0 table.effKind mainEff l passwd := by
  rintro ⟨k, r, -, hm, hmem⟩
  simp [mainEff, Eff.mem, Eff.test, Eff.atoms] at hm
  obtain ⟨rfl, rfl⟩ := hm
  revert hmem
  simp [dataRange, TargetStepExamples.dataRange, passwd, TargetStepExamples.passwd, RangeExpr.Mem,
    RangeExpr.resolve, Range.Mem, PathPattern.Matches]

/-- 開始状態から到達したどの IO の事象の観測にも `/etc/passwd` は現れない（`surface_target_sound` から導く）。 -/
theorem main_never_passwd {evs : List Event} {s s' : State} {b : PrimName} {ws : List Refinement.Val}
    {o : Outcome} {obs : List Target}
    (hsteps : Steps core table σ0 (.run mainClosure [] Store.empty) evs s)
    (hst : Step core table σ0 s (some (.io b ws o obs)) s') : passwd ∉ obs := by
  obtain ⟨e, l, -, -, h⟩ := program_target_sound hsteps hst
  exact fun hm => passwd_not_allowed l (h passwd hm)

end
end Benitoite.Release.Refinement.Surface.TargetWriteExamples
