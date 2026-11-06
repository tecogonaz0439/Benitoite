import Benitoite.Release.Refinement.RangeTyping
import Benitoite.Release.Refinement.ProgramTyping
import Benitoite.Release.Refinement.ScopeSignatures
import Benitoite.Release.Refinement.HostRangeParams

/-! # 範囲パラメータを受け取り、その範囲で読み出す利用者の関数 -/
namespace Benitoite.Release.Refinement.RangeFunctionExamples
noncomputable section
open Scope.Domain

def builtins : Builtins :=
  ScopeSignatures.builtins (fun _ _ _ _ _ => none) (fun _ _ _ _ _ _ => False)

def readResult : Ty := .data "Result" [.base .string, .opaque "IOError" (.fixed .top)]
def readEff (ix : RangeIx) : Eff := .mk (fun a => decide (a = .name "File.Read" ix)) []
def pathTy (ix : RangeIx) : Ty := .opaque "Scope.PathIn" ix
def readTel (ix : RangeIx) : Tel :=
  .param "path" (pathTy ix) (.done readResult (readEff ix))

def readBody : Comp := .app (.prim "File.readTextIn" [] [] [.rvar 0]) [.var 0]

def readerDef : Def where
  tparams := []
  neffs := 0
  rkinds := [.path]
  names := ["path"]
  params := [pathTy (.rvar 0)]
  ret := readResult
  eff := readEff (.rvar 0)
  body := readBody

def program : Program :=
  { ScopeDeclarations.program with defs := fun f => if f = "reader" then some readerDef else none }

theorem reader_signature : readerDef.tel = ScopeSignatures.readTextIn.tel := rfl

private theorem read_atoms (r : RangeExpr) :
    mapRangeAtoms (rangeAt 0 [r])
      (fun a => decide (a = .name "File.Read" (.rvar 0))) =
      (fun a => decide (a = .name "File.Read" (.fixed r))) := by
  funext a
  simp [mapRangeAtoms, mapAtomRanges, mapIx, rangeAt, eq_comm]

private theorem primitive_instTel (r : RangeExpr) :
    Tel.instR [r] ScopeSignatures.readTextIn.tel = readTel (.fixed r) := by
  simp [ScopeSignatures.readTextIn, ScopeSignatures.ioIn, PrimSig.tel, signatureTel,
    Tel.instR, Tel.substRAt, Tel.mapRanges, Tel.rawMapRanges, Ty.rawMapRanges,
    Eff.rawMapRanges, read_atoms, mapIx, rangeAt, Tel.norm, Ty.norm, Ty.normTys,
    Eff.norm, readTel, readResult, readEff, pathTy]

theorem reader_instTel (r : RangeExpr) : readerDef.instTel [r] = readTel (.fixed r) := by
  change Tel.instR [r] readerDef.tel = readTel (.fixed r)
  rw [reader_signature]
  exact primitive_instTel r

private theorem instantiated_read (r : RangeExpr) :
    instantiatedTel (Tel.instR [r] ScopeSignatures.readTextIn.tel) [] [] = readTel (.fixed r) := by
  simp [ScopeSignatures.readTextIn, ScopeSignatures.ioIn, PrimSig.tel, signatureTel,
    instantiatedTel, Tel.instR, Tel.substRAt, Tel.mapRanges, Tel.rawMapRanges,
    Ty.rawMapRanges, Eff.rawMapRanges, read_atoms, mapIx, rangeAt,
    Tel.bind, Tel.rawBind, Ty.rawBind, Eff.rawBind, Tel.norm, Ty.norm, Ty.normTys,
    Eff.norm, typeEnvAt, substAtoms_nil, instAtoms_nil, rowFails, readTel, readResult,
    readEff, pathTy, RangeIx.inst, SubstEnv.up]

private theorem result_annotation (Γ : Ctx) : Ty.Annotation program [] Γ readResult := by
  have ar := (ScopeDeclarations.program_hasHttp.file ScopeDeclarations.result
    (by simp [ScopeDeclarations.file])).1
  exact ⟨by trivial, by trivial, ⟨⟨2, ar, rfl⟩, by trivial⟩⟩

private theorem read_admissible (Γ : Ctx) :
    PrimitiveAdmissible [] Γ.length ScopeSignatures.readTextIn Qempty [] [] := by
  constructor
  · rfl
  · rfl
  · simp
  · rfl
  · simp
  · simp [ScopeSignatures.readTextIn, ScopeSignatures.ioIn, Eff.RowsIn, Ty.RowsInList]
  · intro i h
    simp [Qsig, ScopeSignatures.readTextIn, ScopeSignatures.ioIn, QTys, QTy, QEff,
      Benitoite.Release.Qempty, QTys, QTy, RowTransport] at h
  · intro i h
    simp [Qsig, ScopeSignatures.readTextIn, ScopeSignatures.ioIn, QTys, QTy, QEff,
      Benitoite.Release.Qempty, QTys, QTy, RowTransport] at h
  · simp [ScopeSignatures.readTextIn, ScopeSignatures.ioIn, PrimSig.tel, signatureTel,
      Tel.RowsIn, Ty.RowsIn, Ty.RowsInList, Eff.RowsIn]

private theorem read_signature (Γ : Ctx) (r : RangeExpr) :
    SignatureInstance program [] Γ (Tel.instR [r] ScopeSignatures.readTextIn.tel) [] [] [] := by
  constructor
  · simp [ScopeSignatures.readTextIn, ScopeSignatures.ioIn, PrimSig.tel, signatureTel,
      Tel.instR, Tel.substRAt, Tel.mapRanges, Tel.rawMapRanges, Ty.rawMapRanges,
      Eff.rawMapRanges, read_atoms, mapIx, rangeAt, Ty.WF, Ty.WFList, Tel.WF,
      Tel.norm, Ty.norm, Eff.norm, Eff.WF, Eff.Canonical, RangeIx.WF]
  · simp [TypeAnnotations]
  · exact ⟨rfl, by intro i a k h; cases i <;> cases h⟩
  · simp [RowAnnotations]
  · simp
  · rw [instantiated_read]
    refine ⟨?_, ?_, ?_⟩
    · simp [readTel, pathTy, readResult, readEff, Ty.WF, Ty.WFList, Tel.WF,
        Eff.WF, Eff.Canonical, Eff.norm, RangeIx.WF]
    · simp [readTel, pathTy, readResult, readEff, Ty.Sorted, sortedTys, Tel.Sorted,
        sortedEff]
    · exact ⟨trivial, (result_annotation _).declared, trivial⟩

private theorem read_range (r : RangeExpr) (hf : r.FitsKind .path)
    (hw : r.WF) (hc : r.Canonical) :
    builtins.RangeAdmissible "File.readTextIn" ScopeSignatures.readTextIn [r] := by
  refine ⟨rfl, ?_, ?_, Or.inr ⟨by simp, rfl⟩⟩
  · intro i r' k hr hk
    cases i <;> simp at hr hk
    cases hr; cases hk; exact hf
  · intro r' hr
    cases List.mem_singleton.mp hr
    exact ⟨hw, hc⟩

/-- 任意の適格な path 範囲で、同じ範囲の値だけを読み、同じ範囲の効果を持つ。 -/
theorem closed_read_body (r : RangeExpr) (hf : r.FitsKind .path)
    (hw : r.WF) (hc : r.Canonical) :
    HasTypeCQ program builtins StoreTy.empty Qempty [] [some (pathTy (.fixed r))] []
      (some readResult) (.app (.prim "File.readTextIn" [] [] [.fixed r]) [.var 0])
      readResult (readEff (.fixed r)) [] := by
  have hv := HasTypeVQ.V_Prim (P := program) (B := builtins) (Ψ := StoreTy.empty)
    (Q := Qempty) (C := []) (Γ := [some (pathTy (.fixed r))]) (Φ := []) rfl
    (read_range r hf hw hc)
    (by simp [ScopeSignatures.readTextIn, ScopeSignatures.ioIn, NamesWF])
    (read_admissible _) (read_signature _ r)
  rw [instantiated_read] at hv
  apply HasTypeCQ.C_DependentApp hv
  refine .param ⟨trivial, trivial, trivial⟩ (.V_Var rfl (by simp [pathTy, Ordinary])) ?_
  simp only [Tel.bind_done]
  have hb : readResult.bind (Tel.argumentsEnv (.var 0)) = readResult := by
    simp [readResult, Ty.bind, Ty.rawBind, rawBindTys, Tel.argumentsEnv,
      Ty.norm, Ty.normTys, RangeIx.inst]
  have he : Eff.bind (Tel.argumentsEnv (.var 0)) (readEff (.fixed r)) = readEff (.fixed r) := by
    simp [readEff, Eff.bind, Eff.rawBind, Tel.argumentsEnv, valEnv,
      Eff.norm, substAtoms_nil, instAtoms_nil, rowFails]
  rw [hb, he]
  exact .done ⟨⟨by simp [readResult, Ty.WF, Ty.WFList, RangeIx.WF],
      by simp [readEff, Eff.WF, Ty.WFList], rfl⟩,
    ⟨by simp [readResult, Ty.Sorted, sortedTys], by simp [readEff, sortedEff, sortedTys]⟩,
    ⟨(result_annotation _).declared, trivial⟩⟩

/-- 開いた本体のすべての適格な具体化を、既存の本体の判断で検査する。 -/
theorem reader_body :
    TelBodyTyR program builtins StoreTy.empty Qempty [.path] [] [] [] readerDef.tel
      readerDef.body := by
  simp only [TelBodyTyR, List.cons_ne_self, ↓reduceIte]
  intro rs hr
  have hn : rs.length = 1 := hr.1
  obtain ⟨r, rfl⟩ := List.length_eq_one_iff.mp hn
  have hf : r.FitsKind .path := hr.2.1 0 r .path rfl rfl
  obtain ⟨hw, hc⟩ := hr.2.2 r List.mem_cons_self
  change TelBodyTy program builtins StoreTy.empty Qempty [] [] [] (readerDef.instTel [r])
    (readerDef.body.instR [r])
  rw [reader_instTel]
  apply TelBodyTy.param
  apply TelBodyTy.done
  simpa [readerDef, readBody, readTel, pathTy, Comp.instR, Comp.substR, Comp.mapRangesN,
    Val.mapRangesN, Val.mapRangesListN, mapIx, rangeAt, Ctx.extend, Ty.shiftV] using
    closed_read_body r hf hw hc

private theorem reader_admissible :
    Admissible builtins [] 0 (TypeCtx.constraints readerDef.tparams) readerDef.neffs
      (Qsig readerDef.params readerDef.ret readerDef.eff) Qempty [] [] readerDef.eff := by
  have h := read_admissible ([] : Ctx)
  exact ⟨⟨rfl, by intro i a p h; cases h⟩, h.typeScope, h.rowCount, h.rowScope,
    h.sourceRows, h.sourceQ, h.noFailRows⟩

/-- 関数参照も、引数・結果・効果に同じ具体化を読む。 -/
theorem reader_reference (r : RangeExpr) (hr : RangesFit [r] [.path]) :
    HasTypeVQ program builtins StoreTy.empty Qempty [] [] []
      (.fnRef "reader" [] [] [.fixed r])
      (.dependentFn (instantiatedTel (readerDef.instTel [r]) [] [])) := by
  apply HasTypeVQ.V_Fun (d := readerDef) (rs := [r]) rfl
    (by simp [readerDef, NamesWF]) hr reader_admissible
  have h := read_signature ([] : Ctx) r
  rw [primitive_instTel] at h
  rw [reader_instTel]
  exact h

/-- 範囲変数を持つ参照は、すべての適格な具体化で閉じた関数参照として型が付く。 -/
theorem reader_open_reference :
    HasTypeVQR program builtins [.path] StoreTy.empty Qempty [] [] []
      (.fnRef "reader" [] [] [.rvar 0]) (.dependentFn readerDef.tel) := by
  intro rs hr
  have hn : rs.length = 1 := hr.1
  obtain ⟨r, rfl⟩ := List.length_eq_one_iff.mp hn
  have h := reader_reference r hr
  rw [reader_instTel] at h
  have he : instantiatedTel (readTel (.fixed r)) [] [] = readTel (.fixed r) := by
    simpa only [primitive_instTel] using instantiated_read r
  rw [he] at h
  have hnormal : Tel.norm (readTel (.fixed r)) = readTel (.fixed r) := by
    rw [←primitive_instTel]
    exact Tel.norm_idem _
  have ht : rangeTy [r] (.dependentFn readerDef.tel) =
      (Ty.dependentFn (readTel (.fixed r))).norm := by
    change Ty.foldFn (Tel.instR [r] readerDef.tel) = _
    rw [reader_signature, primitive_instTel]
    simp only [Ty.norm, hnormal]
  rw [ht]
  simpa [rangeCtx, Ctx.mapRanges, Ctx.rawMapRanges, Val.instR, Val.substR,
    Val.mapRangesN, mapIx, rangeAt] using h.V_Normal

theorem reader_annotation :
    Ty.AnnotationR program [.path] [] [] (.dependentFn readerDef.tel) := by
  change Ty.AnnotationR program [.path] [] [] (.dependentFn (readTel (.rvar 0)))
  refine ⟨?_, ?_, ?_⟩
  · simp [readTel, pathTy, readResult, readEff, Ty.WF, Ty.WFList, Tel.WF,
      Eff.WF, Eff.Canonical, Eff.norm, RangeIx.WF]
  · simp [readTel, pathTy, readResult, readEff, Ty.Sorted, sortedTys, Tel.Sorted,
      sortedEff]
  · exact ⟨trivial, (result_annotation _).declared, trivial⟩

theorem reader_kinded : Ty.HasKind program [] (.dependentFn readerDef.tel) .value := by
  have ar : program.DataArity "Result" 2 :=
    (ScopeDeclarations.program_hasHttp.file ScopeDeclarations.result
      (by simp [ScopeDeclarations.file])).1
  change True ∧ (TyCon.arity program (.data "Result") = some 2 ∧ True ∧ True ∧ True) ∧ True
  exact ⟨trivial, ⟨TyCon.arity_data ar, trivial, trivial, trivial⟩, trivial⟩

/-- 種類付きの範囲パラメータを持つ利用者の定義が、本番の宣言の型付けを満たす。 -/
theorem reader_wellTyped : readerDef.WellTyped program builtins := by
  refine ⟨by simp [readerDef, NamesWF], reader_kinded, reader_annotation, ?_⟩
  have hq : QTel readerDef.tel = Qempty := by
    funext i
    simp [readerDef, Def.tel, signatureTel, readResult, readEff, pathTy, QTel, QTy, QEff,
      Benitoite.Release.Qempty, QTys, QTy, RowTransport]
  change TelBodyTyR program builtins StoreTy.empty (QTel readerDef.tel) [.path] [] [] [] readerDef.tel readerDef.body
  rw [hq]
  exact reader_body

/-- 根のパスという通常値を渡す呼出しにも、関数の範囲を具体化した型が付く。 -/
theorem reader_root_call :
    HasTypeCQ program builtins StoreTy.empty Qempty [] [] [] none
      (.app (.fnRef "reader" [] [] [.fixed .top]) [.checked (.path [])])
      readResult (readEff (.fixed .top)) [] := by
  have hr : RangesFit [.top] [.path] := by
    refine ⟨rfl, ?_, ?_⟩
    · intro i r k hi hk
      cases i <;> simp at hi hk
      cases hi; cases hk
      exact Or.inl rfl
    · intro r hr
      cases List.mem_singleton.mp hr
      trivial
  have hv := reader_reference .top hr
  rw [reader_instTel] at hv
  have he : instantiatedTel (readTel (.fixed .top)) [] [] = readTel (.fixed .top) := by
    simpa only [primitive_instTel] using instantiated_read .top
  rw [he] at hv
  apply HasTypeCQ.C_DependentApp hv
  refine .param ⟨trivial, trivial, trivial⟩ ?_ ?_
  · exact .V_Sub (.V_Checked (range := .top) rfl rfl ⟨rfl, trivial⟩) .scoped_forget trivial trivial trivial
  · have hb : readResult.bind (Tel.argumentsEnv (.checked (.path []))) = readResult := by
      simp [readResult, Ty.bind, Ty.rawBind, rawBindTys, Tel.argumentsEnv,
        Ty.norm, Ty.normTys, RangeIx.inst]
    have he : Eff.bind (Tel.argumentsEnv (.checked (.path []))) (readEff (.fixed .top)) =
        readEff (.fixed .top) := by
      simp [readEff, Eff.bind, Eff.rawBind, Tel.argumentsEnv, valEnv,
        Eff.norm, substAtoms_nil, instAtoms_nil, rowFails]
    simp only [Tel.bind_done, hb, he]
    exact .done ⟨⟨by simp [readResult, Ty.WF, Ty.WFList, RangeIx.WF],
        by simp [readEff, Eff.WF, Ty.WFList], rfl⟩,
      ⟨by simp [readResult, Ty.Sorted, sortedTys], by simp [readEff, sortedEff, sortedTys]⟩,
      ⟨(result_annotation _).declared, trivial⟩⟩

private theorem map_empty_ranges (ρ : Nat → RangeIx) :
    mapRangeAtoms ρ (fun _ => false) = (fun _ => false) := by
  funext a
  simp [mapRangeAtoms]

/-- 同じ範囲の対象を受け取り、その対象を返す関数。種類は三種すべてを量化する。 -/
def targetDef (k : Kind) : Def where
  tparams := []
  neffs := 0
  rkinds := [k]
  names := ["target"]
  params := [.scoped "Example.Target" k (.rvar 0)]
  ret := .scoped "Example.Target" k (.rvar 0)
  eff := Eff.empty
  body := .ret (.var 0)

def targetProgram (k : Kind) : Program :=
  { program with defs := fun f => if f = "identity" then some (targetDef k) else none }

def targetBuiltins (k : Kind) : Builtins :=
  { builtins with valKind := fun o => if o = "Example.Target" then some k else builtins.valKind o }

def targetTel (k : Kind) (ix : RangeIx) : Tel :=
  .param "target" (.scoped "Example.Target" k ix)
    (.done (.scoped "Example.Target" k ix) Eff.empty)

def sampleTarget : Kind → Target
  | .path => .path []
  | .host => .host (.name ["example"])
  | .endpoint => .endpoint ⟨.name ["example"], 443⟩

private theorem sample_mem (k : Kind) : Range.MemK k .top (sampleTarget k) := by
  cases k <;> exact ⟨rfl, trivial⟩

theorem target_body (k : Kind) :
    TelBodyTyR (targetProgram k) (targetBuiltins k) StoreTy.empty Qempty [k] [] [] []
      (targetDef k).tel (targetDef k).body := by
  simp only [TelBodyTyR, List.cons_ne_self, ↓reduceIte]
  intro rs hr
  have hn : rs.length = 1 := hr.1
  obtain ⟨r, rfl⟩ := List.length_eq_one_iff.mp hn
  simp [targetDef, Def.tel, signatureTel, rangeCtx, Ctx.mapRanges, Ctx.rawMapRanges,
    rangeTel, Tel.instR, Tel.substRAt, Tel.mapRanges, Tel.rawMapRanges, Ty.rawMapRanges, Eff.rawMapRanges, mapRangeAtoms, map_empty_ranges,
    mapIx, rangeAt, Eff.empty, Comp.instR, Comp.substR, Comp.mapRangesN,
    Val.mapRangesN, Ty.shiftV, Tel.norm, Ty.norm, Ty.normTys, Eff.norm]
  apply TelBodyTy.param
  apply TelBodyTy.done
  apply HasTypeCQ.C_Return
  exact .V_Var rfl (by simp [Ordinary])

private theorem target_admissible (k : Kind) :
    Admissible (targetBuiltins k) [] 0 (TypeCtx.constraints (targetDef k).tparams)
      (targetDef k).neffs
      (Qsig (targetDef k).params (targetDef k).ret (targetDef k).eff)
      Qempty [] [] (targetDef k).eff := by
  constructor
  · exact ⟨rfl, by intro i a p h; cases h⟩
  · simp
  · rfl
  · simp
  · simp [targetDef, Eff.RowsIn, Eff.empty, Ty.RowsInList]
  · simp [targetDef, Qsig, QTys, QTy, QEff, Eff.empty, Benitoite.Release.Qempty, QTys, QTy, RowTransport]
  · simp [targetDef, Qsig, QTys, QTy, QEff, Eff.empty, Benitoite.Release.Qempty, QTys, QTy, RowTransport]

private theorem target_instTel (k : Kind) (r : RangeExpr) :
    (targetDef k).instTel [r] = targetTel k (.fixed r) := by
  simp [Def.instTel, targetDef, Def.tel, signatureTel, targetTel,
    Tel.rawMapRanges, Ty.rawMapRanges, Eff.rawMapRanges, mapRangeAtoms, mapIx,
    rangeAt, Eff.empty, map_empty_ranges, Tel.instR, Tel.substRAt, Tel.mapRanges, Tel.norm, Ty.norm, Ty.normTys, Eff.norm]

theorem target_reference (k : Kind) (r : RangeExpr) (hr : RangesFit [r] [k]) :
    HasTypeVQ (targetProgram k) (targetBuiltins k) StoreTy.empty Qempty [] [] []
      (.fnRef "identity" [] [] [.fixed r]) (.dependentFn (targetTel k (.fixed r))) := by
  have hsig : SignatureInstance (targetProgram k) [] [] ((targetDef k).instTel [r]) [] [] [] := by
    rw [target_instTel]
    constructor
    · simp [targetTel, Ty.WF, Ty.WFList, RangeIx.WF, sortedTys, declaredTys, Tel.WF, Eff.WF, Eff.Canonical, Eff.norm, Eff.empty, RangeIx.WF]
    · simp [TypeAnnotations]
    · exact ⟨rfl, by intro i a k h; cases i <;> cases h⟩
    · simp [RowAnnotations]
    · simp
    · constructor <;>
        simp [targetTel, instantiatedTel, Tel.bind, Tel.rawBind, Ty.rawBind, Eff.rawBind,
          Tel.norm, Ty.norm, Eff.norm, Eff.empty, typeEnvAt, RangeIx.inst, Ty.WF, Tel.WF,
          Eff.WF, Eff.Canonical, Ty.Sorted, Tel.Sorted, sortedEff, Ty.Declared, Tel.Declared,
          declaredEff, Ty.normTys, rowFails, substAtoms_nil, instAtoms_nil, Ty.WFList, RangeIx.WF, sortedTys, declaredTys]
  have h := HasTypeVQ.V_Fun (P := targetProgram k) (B := targetBuiltins k)
    (Ψ := StoreTy.empty) (Q := Qempty) (C := []) (Γ := []) (Φ := [])
    (f := "identity") (d := targetDef k) (rs := [r]) rfl (by simp [targetDef, NamesWF]) hr
    (target_admissible k) hsig
  rw [target_instTel] at h
  simpa [targetTel, instantiatedTel, Tel.bind, Tel.rawBind, Ty.rawBind, Eff.rawBind,
    Tel.norm, Ty.norm, Eff.norm, Eff.empty, typeEnvAt, RangeIx.inst,
    Ty.normTys, rowFails, substAtoms_nil, instAtoms_nil, Ty.WFList, RangeIx.WF, sortedTys, declaredTys] using h

/-- path・host・endpoint の各種類で、実際の対象値を返す具体化済み関数を呼べる。 -/
theorem target_call_top (k : Kind) :
    HasTypeCQ (targetProgram k) (targetBuiltins k) StoreTy.empty Qempty [] [] [] none
      (.app (.fnRef "identity" [] [] [.fixed .top]) [.checked (sampleTarget k)])
      (.scoped "Example.Target" k (.fixed .top)) Eff.empty [] := by
  have hr : RangesFit [.top] [k] := by
    refine ⟨rfl, ?_, ?_⟩
    · intro i r k' hi hk
      cases i <;> simp at hi hk
      cases hi; cases hk
      exact Or.inl rfl
    · intro r hr
      cases List.mem_singleton.mp hr
      trivial
  apply HasTypeCQ.C_DependentApp (target_reference k .top hr)
  refine .param ⟨trivial, trivial, trivial⟩ ?_ ?_
  · exact .V_Checked rfl rfl (sample_mem k)
  · simp [targetTel, Tel.bind, Tel.rawBind, Tel.argumentsEnv, typeEnvAt, valEnv,
      Ty.rawBind, Ty.norm, Eff.rawBind, Eff.norm, Eff.empty, Ty.normTys,
      RangeIx.inst, substAtoms_nil, instAtoms_nil, rowFails]
    exact .done ⟨⟨trivial, trivial, rfl⟩, ⟨trivial, trivial⟩, ⟨trivial, trivial⟩⟩

/-- host の非 Top の条件も、種類の照合を通った範囲として関数へ渡せる。 -/
theorem target_host_reference (p : HostPattern) (hw : p.WF) (hc : p.Canonical) :
    HasTypeVQ (targetProgram .host) (targetBuiltins .host) StoreTy.empty Qempty [] [] []
      (.fnRef "identity" [] [] [.fixed (.host p)])
      (.dependentFn (targetTel .host (.fixed (.host p)))) := by
  apply target_reference
  refine ⟨rfl, ?_, ?_⟩
  · intro i r k hi hk
    cases i <;> simp at hi hk
    cases hi; cases hk
    exact (RangeExpr.fitsKind_host_iff _).mpr (Or.inr ⟨p, rfl⟩)
  · intro r hr
    cases List.mem_singleton.mp hr
    exact ⟨hw, hc⟩

/-- 対象を返す利用者の定義は、path・host・endpoint の全種類で検査を通る。 -/
theorem target_wellTyped (k : Kind) :
    (targetDef k).WellTyped (targetProgram k) (targetBuiltins k) := by
  refine ⟨by simp [targetDef, NamesWF], ?_, ?_, ?_⟩
  · trivial
  · constructor <;>
      simp [targetDef, Def.tel, signatureTel, Ty.WF, Tel.WF, RangeIx.WF,
        Eff.WF, Eff.Canonical, Eff.norm, Eff.empty, Ty.Sorted, Tel.Sorted, sortedEff,
        Ty.Declared, Tel.Declared, declaredEff, Ty.WFList, sortedTys, declaredTys]
  · have hq : QTel (targetDef k).tel = Qempty := by
      funext i
      simp [targetDef, Def.tel, signatureTel, QTel, QTy, QEff, Eff.empty,
        Benitoite.Release.Qempty, QTys, QTy, RowTransport]
    change TelBodyTyR (targetProgram k) (targetBuiltins k) StoreTy.empty (QTel (targetDef k).tel) [k] [] [] [] (targetDef k).tel (targetDef k).body
    rw [hq]
    exact target_body k

end
end Benitoite.Release.Refinement.RangeFunctionExamples
