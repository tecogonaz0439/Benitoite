import Benitoite.Release.Refinement.InversionCore
import Benitoite.Release.Refinement.ScopeSignatures
import Benitoite.Release.Refinement.HostRangeParams
import Benitoite.Release.Refinement.Typing

namespace Benitoite.Release.Refinement.CanonicalResumeTrial
noncomputable section
open Scope.Domain

mutual
  /-- 値。 -/
  inductive Val where
    | var (i : Nat)
    | const (c : Const)
    | fnRef (f : FunName) (tys : List Ty) (effs : List Eff) (rs : List RangeIx)
    /-- 組み込みの関数 `b[T̄; Ē; R̄]`。`rs` は具体化した範囲の列。 -/
    | prim (b : PrimName) (tys : List Ty) (effs : List Eff) (rs : List RangeIx)
    | lam (names : List String) (params : List Ty) (body : Comp)
    | dependentLam (signature : Tel) (body : Comp)
    | closure (signature : Tel) (body : Closure)
    | con (c : ConName) (tys : List Ty) (args : List Val)
    | list (elems : List Val)
    /-- 利用者が宣言したエフェクトの操作 `op[T̄]`。 -/
    | op (o : OpName) (tys : List Ty)
    /-- 型付きの中断。結果型は節の内側で一つ束縛する。 -/
    | raise (result error : Ty)
    /-- ストアの場所 ℓ（可変のセルと明示遅延）と、継続の場所 κ。 -/
    | loc (l : Nat)
    /-- マップ `{V1 ↦ W1, …, Vn ↦ Wn}`。鍵の並びと値の並びで表す。 -/
    | mapV (keys : List Val) (vals : List Val)
    /-- 集合 `{V1, …, Vn}`。 -/
    | setV (elems : List Val)
    /-- バイト列 `bytes(k1, …, kn)`。ki は `Byte` の値（`Const.byte` と同じく自然数で表す）。 -/
    | bytesV (bs : List Nat)
    /-- 実装の辞書 `I[T̄](V̄)`。 -/
    | dict (i : ImplName) (tys : List Ty) (args : List Val)
    /-- 上位の型クラスの辞書 `V↑S`。 -/
    | super (v : Val) (s : ClassName)
    /-- 検査済みの対象。対象自身に型や値の自由変数はない（設計書 01-12「構文」）。 -/
    | externalRef (id : ExternalFunctionId) (types : List Ty)
    | externalHandle (handle : ExternalHandle) (types : List Ty)
    | pathBases (snapshot : PathEnv)
    | scopePattern (range : RangeExpr)
    | checkedAt (range : RangeExpr) (snapshot : Option PathEnv)
        (target : Scope.Domain.Target) (request : Option Val)
    | atError (detail : Detail Val)
    | checked (t : Scope.Domain.Target)
    /-- 要求と検査済みの endpoint を保持する。型付けの葉では閉じた要求の型付けに加え、
    groundVal と reqTarget による端点一致を検査する。葉の規則は構文と別に追加する。 -/
    | checkedRequest (t : Scope.Domain.Target) (req : Val)

  inductive Comp where
    | builderLet (kind : BuilderKind) (body : Comp)
    | builderOp (kind : BuilderKind) (op : BuilderOp) (ref : LocalRef) (args : List Val)
    | ret (v : Val)
    | letIn (m : Comp) (n : Comp)
    | app (f : Val) (args : List Val)
    | ite (v : Val) (m n : Comp)
    /-- 選択肢とガードを持つ照合。Release の照合はこの構成の一種類だけである。 -/
    | «match» (v : Val) (arms : List Arm)
    /-- `lazy M` -/
    | lazyC (m : Comp)
    /-- `escape V` -/
    | escape (v : Val)
    /-- `use V in M` -/
    | use (v : Val) (m : Comp)
    /-- `handle M with H` -/
    | handle (m : Comp) (h : List Clause)
    /-- `resume κ V`。κ は節の変数か、継続の場所。 -/
    | resume (k : Val) (v : Val)
    /-- メソッドの呼び出し `V.m[S̄; Ē](W̄)`。 -/
    | externalCall (id : ExternalFunctionId) (types : List Ty) (arguments : List Val)
    | issuePathBases (primitive : PrimName)
    | checkAt (kind : Scope.Domain.Kind) (name : OpaqueName) (result : ResultShape)
        (bases : Option Val) (pattern input : Val) (index : RangeIx)
    | meth (d : Val) (m : MethName) (tys : List Ty) (effs : List Eff) (args : List Val)

  /-- 節 `op(x̄) k ⇒ N`。`arity` は x̄ の個数、`ntys` は操作の型パラメータの個数である。N の中で、番号 0 が k、
  番号 1 から n が x̄ を最後の引数から順に指す。操作の型パラメータは、N の中の型の変数の番号 `0..ntys-1` である。 -/
  inductive Clause where
    | mk (op : OpRef) (arity : Nat) (ntys : Nat) (body : Comp)
    /-- 0番は利用不能、1番はエラーであり、本体だけが結果型を束縛する。 -/
    | fail (error : Ty) (body : Comp)

  /-- 照合の分岐。本体とガードは分岐ごとに一つだけ持つ。 -/
  inductive Arm where
    | mk (alts : List Alt) (guard : Option Comp) (body : Comp)
  inductive Capture where
    | mk (values : List (Option Val))

  inductive Closure where
    | mk (capture : Capture) (code : Comp)
end

structure Def where
  tparams : List TParamDecl
  neffs : Nat
  rkinds : List Kind := []
  names : List String
  params : List Ty
  ret : Ty
  eff : Eff
  body : Comp

structure Program where
  declarations : Benitoite.Release.Refinement.Program
  defs : FunName → Option Def

def Def.tel (d : Def) : Tel := signatureTel d.names d.params d.ret d.eff

def RangesFit (rs : List RangeExpr) (ks : List Kind) : Prop :=
  rs.length = ks.length ∧
  (∀ (i : Nat) (r : RangeExpr) (k : Kind), rs[i]? = some r → ks[i]? = some k → r.FitsKind k) ∧
  (∀ r ∈ rs, r.WF ∧ r.Canonical)

def FitsIx (ks : List Kind) (ix : RangeIx) (k : Kind) : Prop := match ix with
  | .fixed r => r.FitsKind k ∧ r.WF ∧ r.Canonical
  | .rvar i => ks[i]? = some k

def RangesFitIx (ks : List Kind) (rs : List RangeIx) (target : List Kind) : Prop :=
  rs.length = target.length ∧
  ∀ (i : Nat) (r : RangeIx) (k : Kind), rs[i]? = some r → target[i]? = some k → FitsIx ks r k

def closeIx (rs : List RangeExpr) (ix : RangeIx) : RangeExpr := match ix with
  | .fixed r => r
  | .rvar i => (rs[i]?).getD .top

def instantiateArgs (rs : List RangeExpr) (args : List RangeIx) : List RangeIx :=
  args.map (RangeIx.inst rs)

def ixAt (rs : List RangeIx) (i : Nat) : RangeIx := (rs[i]?).getD (.rvar i)

def Tel.instR (rs : List RangeIx) (t : Tel) : Tel :=
  Benitoite.Release.Refinement.Tel.mapRanges (ixAt rs) t

def Ty.AnnotationR (P : Benitoite.Release.Refinement.Program) (ks : List Kind)
    (C : TypeCtx) (Γ : Ctx) (a : Ty) : Prop :=
  a.WF ks.length C.length Γ.length ∧ a.Sorted Γ ∧ a.Declared P C Γ

structure SignatureInstanceR (P : Benitoite.Release.Refinement.Program) (ks : List Kind)
    (C : TypeCtx) (Γ : Ctx) (t : Tel) (kinds : List TyKind) (ts : List Ty) (es : List Eff) : Prop where
  source : (Ty.dependentFn t).WF ks.length kinds.length 0
  types : ∀ t ∈ ts, Ty.AnnotationR P ks C Γ t
  kinds : TypeArgsKinded P C ts kinds
  rows : ∀ e ∈ es, Ty.AnnotationR P ks C Γ (.fn [] [] (.base .unit) e)
  rowKinds : ∀ e ∈ es, kindsEff P (TypeCtx.kinds C) e
  result : Ty.AnnotationR P ks C Γ (.dependentFn (instantiatedTel t ts es))

structure AdmissibleR (B : Builtins) (ks : List Kind) (C : TypeCtx) (nv : Nat)
    (tps : List TParam) (ne : Nat) (Qs Qt : NoFailCtx)
    (ts : List Ty) (es : List Eff) (e : Eff) : Prop where
  types : ∀ rs, RangesFit rs ks → SatAll B C (ts.map (Benitoite.Release.Refinement.Ty.instR rs)) tps
  typeScope : ∀ t ∈ ts, Ty.WF ks.length C.length nv t ∧ Ordinary t
  rowCount : es.length = ne
  rowScope : ∀ f ∈ es, Eff.WF ks.length C.length nv f
  sourceRows : Eff.RowsIn (· < es.length) e
  sourceQ : ∀ i, Qs i → i < es.length
  noFailRows : RowTransport Qs Qt es

structure PrimitiveAdmissibleR (ks : List Kind) (C : TypeCtx) (nv : Nat) (s : PrimSig)
    (Q : NoFailCtx) (ts : List Ty) (es : List Eff) : Prop where
  typeCount : ts.length = s.tparams.length
  admits : ∀ rs, RangesFit rs ks → s.admits (TypeCtx.constraints C)
    (Ty.normTys (ts.map (Benitoite.Release.Refinement.Ty.instR rs)))
  typeScope : ∀ t ∈ ts, Ty.WF ks.length C.length nv t ∧ Ordinary t
  rowCount : es.length = s.neffs
  rowScope : ∀ f ∈ es, Eff.WF ks.length C.length nv f
  sourceRows : Eff.RowsIn (· < es.length) s.eff
  sourceQ : ∀ i, Qsig s.params s.ret s.eff i → i < es.length
  noFailRows : RowTransport (Qsig s.params s.ret s.eff) Q es
  sourceTelRows : s.tel.RowsIn (· < es.length)

def Def.RangeAdmissible (ks : List Kind) (d : Def) (rs : List RangeIx) : Prop :=
  RangesFitIx ks rs d.rkinds

def Builtins.RangeAdmissibleR (B : Builtins) (ks : List Kind) (b : PrimName)
    (s : PrimSig) (rs : List RangeIx) : Prop :=
  RangesFitIx ks rs s.rkinds ∧
  ∀ ρ, RangesFit ρ ks →
    ((∀ r ∈ rs.map (closeIx ρ), r = .absolute .top) ∨ B.admitsR b (rs.map (closeIx ρ)))

inductive HasTypeVQ (P : Program) (B : Builtins) (ks : List Kind) :
    StoreTy → NoFailCtx → TypeCtx → Ctx → List Pred → Val → Ty → Prop where
  | V_Var {Ψ Q C Γ Φ i a} : Γ[i]? = some (some a) → Ordinary a →
      HasTypeVQ P B ks Ψ Q C Γ Φ (.var i) a
  | V_Fun {Ψ Q C Γ Φ f d ts es rs} : P.defs f = some d → NamesWF d.names d.params →
      Def.RangeAdmissible ks d rs →
      AdmissibleR B ks C Γ.length (TypeCtx.constraints d.tparams) d.neffs
        (Qsig d.params d.ret d.eff) Q ts es d.eff →
      SignatureInstanceR P.declarations ks C Γ (Tel.instR rs d.tel) (TypeCtx.kinds d.tparams) ts es →
      HasTypeVQ P B ks Ψ Q C Γ Φ (.fnRef f ts es rs)
        (.dependentFn (instantiatedTel (Tel.instR rs d.tel) ts es))
  | V_Prim {Ψ Q C Γ Φ b s ts es rs} : B.sig b = some s → Builtins.RangeAdmissibleR B ks b s rs →
      NamesWF s.names s.params → PrimitiveAdmissibleR ks C Γ.length s Q ts es →
      SignatureInstanceR P.declarations ks C Γ (Tel.instR rs s.tel) (TypeCtx.kinds s.tparams) ts es →
      HasTypeVQ P B ks Ψ Q C Γ Φ (.prim b ts es rs)
        (.dependentFn (instantiatedTel (Tel.instR rs s.tel) ts es))


def readResult : Ty := .data "Result" [.base .string,.opaque "IOError" .top]
def readEff (ix : RangeIx) : Eff := .mk (fun a => decide (a = .name "File.Read" ix)) []
def pathTy (ix : RangeIx) : Ty := .opaque "Scope.PathIn" ix

def readTel (ix : RangeIx) : Tel :=
  .param "path" (pathTy ix) (.done readResult (readEff ix))

theorem instantiated_read (ix : RangeIx) :
    instantiatedTel (Tel.instR [ix] ScopeSignatures.readTextIn.tel) [] [] = readTel ix := by
  have atoms : mapRangeAtoms (ixAt [ix])
      (fun a => decide (a = .name "File.Read" (.rvar 0))) =
      (fun a => decide (a = .name "File.Read" ix)) := by
    funext a
    simp [mapRangeAtoms,mapAtomRanges,mapIx,ixAt,eq_comm]
  simp [ScopeSignatures.readTextIn,ScopeSignatures.ioIn,PrimSig.tel,signatureTel,
    instantiatedTel,Tel.instR,Benitoite.Release.Refinement.Tel.mapRanges,
    Benitoite.Release.Refinement.Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,atoms,ixAt,mapIx,
    Benitoite.Release.Refinement.Tel.bind,Benitoite.Release.Refinement.Tel.rawBind,
    Ty.rawBind,Eff.rawBind,Benitoite.Release.Refinement.Tel.norm,Ty.norm,Ty.normTys,
    Eff.norm,typeEnvAt,substAtoms_nil,instAtoms_nil,rowFails,readTel,readResult,readEff,pathTy,
    RangeIx.inst,SubstEnv.up]
  cases ix <;> rfl

def B : Builtins := ScopeSignatures.builtins (fun _ _ _ _ _ => none) (fun _ _ _ _ _ _ => False)
def P : Program := ⟨ScopeDeclarations.program,fun _ => none⟩

theorem read_result_annotation (ks : List Kind) (Γ : Ctx) :
    Ty.AnnotationR ScopeDeclarations.program ks [] Γ readResult := by
  have ar := (ScopeDeclarations.program_hasHttp.file ScopeDeclarations.result (by simp [ScopeDeclarations.file])).1
  exact ⟨by trivial,by trivial,⟨⟨2,ar,rfl⟩,by trivial⟩⟩

theorem read_admissible (ks : List Kind) (Γ : Ctx) :
    PrimitiveAdmissibleR ks [] Γ.length ScopeSignatures.readTextIn Qempty [] [] := by
  constructor
  · rfl
  · intro rs _; rfl
  · simp
  · rfl
  · simp
  · simp [ScopeSignatures.readTextIn,ScopeSignatures.ioIn,Eff.RowsIn,Ty.RowsInList]
  · intro i h
    simp [Qsig,ScopeSignatures.readTextIn,ScopeSignatures.ioIn,QTys,QTy,QEff,Benitoite.Release.Qempty] at h
  · intro i h
    simp [Qsig,ScopeSignatures.readTextIn,ScopeSignatures.ioIn,QTys,QTy,QEff,Benitoite.Release.Qempty] at h
  · simp [ScopeSignatures.readTextIn,ScopeSignatures.ioIn,PrimSig.tel,signatureTel,
      Benitoite.Release.Refinement.Tel.RowsIn,Ty.RowsIn,Ty.RowsInList,Eff.RowsIn]

theorem read_signature (ks : List Kind) (Γ : Ctx) (ix : RangeIx) (hw : ix.WF ks.length) :
    SignatureInstanceR ScopeDeclarations.program ks [] Γ
      (Tel.instR [ix] ScopeSignatures.readTextIn.tel) [] [] [] := by
  constructor
  · simp [ScopeSignatures.readTextIn,ScopeSignatures.ioIn,PrimSig.tel,signatureTel,Tel.instR,
      Benitoite.Release.Refinement.Tel.mapRanges,Benitoite.Release.Refinement.Tel.rawMapRanges,
      Ty.rawMapRanges,Eff.rawMapRanges,Ty.WF,Ty.WFList,Benitoite.Release.Refinement.Tel.WF,
      Benitoite.Release.Refinement.Tel.norm,Ty.norm,Eff.norm,Eff.WF,Eff.Canonical,ixAt,mapIx,RangeIx.WF]
    exact hw
  · simp
  · exact ⟨rfl,by intro i a k h; cases i <;> cases h⟩
  · simp
  · simp
  · rw [instantiated_read]
    refine ⟨?_,?_,?_⟩
    · simp [readTel,pathTy,readResult,readEff,Ty.WF,Ty.WFList,
        Benitoite.Release.Refinement.Tel.WF,Eff.WF,Eff.Canonical,Eff.norm,RangeIx.WF]
      exact hw
    · simp [readTel,pathTy,readResult,readEff,Ty.Sorted,sortedTys,
        Benitoite.Release.Refinement.Tel.Sorted,sortedEff]
    · exact ⟨trivial,(read_result_annotation ks _).2.2,trivial⟩


theorem read_range_admissible (ks : List Kind) (ix : RangeIx) (hi : FitsIx ks ix .path) :
    Builtins.RangeAdmissibleR B ks "File.readTextIn" ScopeSignatures.readTextIn [ix] := by
  constructor
  · refine ⟨rfl,?_⟩
    intro i r k hr hk
    cases i <;> simp at hr hk
    cases hr; cases hk; exact hi
  · intro ρ _
    right
    exact ⟨by simp,rfl⟩

theorem fitsIx_wf {ks ix k} (h : FitsIx ks ix k) : ix.WF ks.length := by
  cases ix with
  | fixed r => trivial
  | rvar i => exact (List.getElem?_eq_some_iff.mp h).choose

theorem read_value (ks : List Kind) (ix : RangeIx) (hi : FitsIx ks ix .path) (Γ : Ctx) :
    HasTypeVQ P B ks StoreTy.empty Qempty [] Γ [] (.prim "File.readTextIn" [] [] [ix])
      (.dependentFn (readTel ix)) := by
  rw [←instantiated_read ix]
  exact .V_Prim rfl (read_range_admissible ks ix hi)
    (by simp [ScopeSignatures.readTextIn,ScopeSignatures.ioIn,NamesWF])
    (read_admissible ks Γ) (read_signature ks Γ ix (fitsIx_wf hi))

/-- 代表入力の範囲具体化。型・行・項の引数列を同じ置換で具体化する。 -/
def readBody (ix : RangeIx) : Comp := .app (.prim "File.readTextIn" [] [] [ix]) [.var 0]

def closedReadBody (r : RangeExpr) : Benitoite.Release.Refinement.Comp :=
  .app (.prim "File.readTextIn" [] [] [r]) [.var 0]

/-- 閉じた既存の判断へ戻して、試行用の規則で単に型が付いたと宣言していないことを検査する。 -/
theorem closed_read_body (r : RangeExpr) (hf : r.FitsKind .path) (hw : r.WF) (hc : r.Canonical) :
    Benitoite.Release.Refinement.HasTypeCQ ScopeDeclarations.program B StoreTy.empty Qempty []
      [some (pathTy (.fixed r))] [] (some readResult) (closedReadBody r) readResult (readEff (.fixed r)) [] := by
  have hs := read_signature [] [some (pathTy (.fixed r))] (.fixed r) trivial
  have hsi : SignatureInstance ScopeDeclarations.program [] [some (pathTy (.fixed r))]
      (Benitoite.Release.Refinement.Tel.instR [r] ScopeSignatures.readTextIn.tel) [] [] [] := by
    have he : Tel.instR [.fixed r] ScopeSignatures.readTextIn.tel =
        Benitoite.Release.Refinement.Tel.instR [r] ScopeSignatures.readTextIn.tel := by
      unfold Tel.instR Benitoite.Release.Refinement.Tel.instR Benitoite.Release.Refinement.Tel.substRAt
      congr 1
      funext i
      cases i <;> simp [ixAt,rangeAt]
    rw [he] at hs
    exact ⟨hs.source,by simp [TypeAnnotations],hs.kinds,by simp [RowAnnotations],hs.rowKinds,
      ⟨hs.result.1,hs.result.2.1,hs.result.2.2⟩⟩
  have ha := read_admissible [] [some (pathTy (.fixed r))]
  have hap : PrimitiveAdmissible [] 1 ScopeSignatures.readTextIn Qempty [] [] := by
    exact ⟨ha.typeCount,rfl,ha.typeScope,ha.rowCount,ha.rowScope,ha.sourceRows,ha.sourceQ,
      ha.noFailRows,ha.sourceTelRows⟩
  have har : B.RangeAdmissible "File.readTextIn" ScopeSignatures.readTextIn [r] := by
    refine ⟨rfl,?_,?_,Or.inr ⟨by simp,rfl⟩⟩
    · intro i r' k hr hk
      cases i <;> simp at hr hk
      cases hr; cases hk; exact hf
    · intro r' hr; cases List.mem_singleton.mp hr
      exact ⟨hw,hc⟩
  have hv := Benitoite.Release.Refinement.HasTypeVQ.V_Prim (P := ScopeDeclarations.program)
    (B := B) (Ψ := StoreTy.empty) (Q := Qempty) (C := [])
    (Γ := [some (pathTy (.fixed r))]) (Φ := []) rfl har
    (by simp [ScopeSignatures.readTextIn,ScopeSignatures.ioIn,NamesWF]) hap hsi
  have he : Benitoite.Release.Refinement.Tel.instR [r] ScopeSignatures.readTextIn.tel =
      Tel.instR [.fixed r] ScopeSignatures.readTextIn.tel := by
    unfold Tel.instR Benitoite.Release.Refinement.Tel.instR Benitoite.Release.Refinement.Tel.substRAt
    congr 1
    funext i
    cases i <;> simp [ixAt,rangeAt]
  rw [he,instantiated_read] at hv
  apply Benitoite.Release.Refinement.HasTypeCQ.C_DependentApp hv
  refine .param ⟨trivial,trivial,trivial⟩ (.V_Var rfl (by simp [pathTy,Ordinary])) ?_
  simp only [Benitoite.Release.Refinement.Tel.bind_done]
  have hb : readResult.bind (Benitoite.Release.Refinement.Tel.argumentsEnv (.var 0)) = readResult := by
    simp [readResult,Ty.bind,Ty.rawBind,rawBindTys,Benitoite.Release.Refinement.Tel.argumentsEnv,
      Ty.norm,Ty.normTys,RangeIx.inst]
  have he : Eff.bind (Benitoite.Release.Refinement.Tel.argumentsEnv (.var 0)) (readEff (.fixed r)) = readEff (.fixed r) := by
    simp [readEff,Eff.bind,Eff.rawBind,Benitoite.Release.Refinement.Tel.argumentsEnv,valEnv,
      Eff.norm,substAtoms_nil,instAtoms_nil,rowFails]
  rw [hb,he]
  exact .done ⟨⟨by simp [readResult,Ty.WF,Ty.WFList,RangeIx.WF],by simp [readEff,Eff.WF,Ty.WFList],rfl⟩,
    ⟨by simp [readResult,Ty.Sorted,sortedTys],by simp [readEff,sortedEff,sortedTys]⟩,
    ⟨(read_result_annotation [] _).2.2,trivial⟩⟩

end
end Benitoite.Release.Refinement.CanonicalResumeTrial

namespace Benitoite.Release.Refinement.CanonicalResumeTrial
noncomputable section
open Scope.Domain

def readerDef : Def where
  tparams := []
  neffs := 0
  rkinds := [.path]
  names := ["path"]
  params := [pathTy (.rvar 0)]
  ret := readResult
  eff := readEff (.rvar 0)
  body := readBody (.rvar 0)

def readerProgram : Program := ⟨ScopeDeclarations.program,
  fun f => if f = "reader" then some readerDef else none⟩

theorem reader_signature : readerDef.tel = ScopeSignatures.readTextIn.tel := rfl

theorem reader_reference (ks : List Kind) (ix : RangeIx) (hi : FitsIx ks ix .path) :
    HasTypeVQ readerProgram B ks StoreTy.empty Qempty [] [] [] (.fnRef "reader" [] [] [ix])
      (.dependentFn (readTel ix)) := by
  rw [←instantiated_read ix,←reader_signature]
  have ha := read_admissible ks ([] : Ctx)
  apply HasTypeVQ.V_Fun (d := readerDef) (rs := [ix]) rfl
    (by simp [readerDef,NamesWF])
    (show Def.RangeAdmissible ks readerDef [ix] from (read_range_admissible ks ix hi).1) ?_
    (by change SignatureInstanceR ScopeDeclarations.program ks [] [] (Tel.instR [ix] readerDef.tel) [] [] []
        rw [reader_signature]
        exact read_signature ks [] ix (fitsIx_wf hi))
  exact ⟨by intro ρ _; exact ⟨rfl,by intro i t p ht; cases ht⟩,
    ha.typeScope,ha.rowCount,ha.rowScope,ha.sourceRows,ha.sourceQ,ha.noFailRows⟩

/-- 任意の適格な具体化で、同じ R が引数の型・原始関数の引数列・効果へ入る。 -/
theorem reader_specializes (r : RangeExpr) (hf : r.FitsKind .path) (hw : r.WF) (hc : r.Canonical) :
    HasTypeVQ readerProgram B [.path] StoreTy.empty Qempty [] [] []
      (.fnRef "reader" [] [] [.rvar 0]) (.dependentFn (readTel (.rvar 0))) ∧
    instantiateArgs [r] [.rvar 0] = [.fixed r] ∧
    HasTypeVQ readerProgram B [] StoreTy.empty Qempty [] [] []
      (.fnRef "reader" [] [] [.fixed r]) (.dependentFn (readTel (.fixed r))) ∧
    Benitoite.Release.Refinement.HasTypeCQ ScopeDeclarations.program B StoreTy.empty Qempty []
      [some (pathTy (.fixed r))] [] (some readResult) (closedReadBody r) readResult (readEff (.fixed r)) [] :=
  ⟨reader_reference [.path] (.rvar 0) rfl,rfl,
    reader_reference [] (.fixed r) ⟨hf,hw,hc⟩,closed_read_body r hf hw hc⟩

end
end Benitoite.Release.Refinement.CanonicalResumeTrial

namespace Benitoite.Release.Refinement.CanonicalResumeTrial
noncomputable section

/-- 固定済みの関数の正準形の結論を、拡張した構文の上でそのまま読んだ形。 -/
def OldFunctionShape (v : Val) : Prop :=
  (∃ f ts es, v = .fnRef f ts es []) ∨
  (∃ b ts es rs, v = .prim b ts es rs) ∨
  (∃ o ts, v = .op o ts) ∨
  (∃ ns ps body, v = .lam ns ps body) ∨
  (∃ t body, v = .dependentLam t body) ∨
  (∃ runtime body, v = .closure runtime body) ∨
  (∃ t e, v = .raise t e) ∨ (∃ f ts, v = .externalRef f ts)

theorem nonempty_ref_excludes_old_shape (f : FunName) (ts : List Ty) (es : List Eff)
    (r : RangeIx) (rs : List RangeIx) : ¬ OldFunctionShape (.fnRef f ts es (r :: rs)) := by
  simp [OldFunctionShape]

/-- 適格な全 path 具体化で型付く関数参照が、範囲なしの正準形の結論を満たさない。 -/
theorem canonical_obstruction (r : RangeExpr) (hf : r.FitsKind .path)
    (hw : r.WF) (hc : r.Canonical) :
    HasTypeVQ readerProgram B [] StoreTy.empty Qempty [] [] []
      (.fnRef "reader" [] [] [.fixed r]) (.dependentFn (readTel (.fixed r))) ∧
    (Ty.dependentFn (readTel (.fixed r))).fnCore = some (readTel (.fixed r)) ∧
    ¬ OldFunctionShape (.fnRef "reader" [] [] [.fixed r]) :=
  ⟨reader_reference [] (.fixed r) ⟨hf,hw,hc⟩,rfl,
    nonempty_ref_excludes_old_shape _ _ _ _ _⟩

/-- 前提は Top の正常な具体化でも満たされる。 -/
theorem concrete_obstruction :
    HasTypeVQ readerProgram B [] StoreTy.empty Qempty [] [] []
      (.fnRef "reader" [] [] [.fixed .top]) (.dependentFn (readTel (.fixed .top))) ∧
    (Ty.dependentFn (readTel (.fixed .top))).fnCore = some (readTel (.fixed .top)) ∧
    ¬ OldFunctionShape (.fnRef "reader" [] [] [.fixed .top]) :=
  canonical_obstruction .top (Scope.Domain.Range.top_fitsKind _) trivial trivial

/-- 旧結論を新しい値の構文の全入力に対して要求する言明。 -/
def OldCanonicalStatement : Prop :=
  ∀ (P : Program) (B : Builtins) (Ψ : StoreTy) (Q : NoFailCtx)
    (C : TypeCtx) (Φ : List Pred) (v : Val) (T : Ty) (t : Benitoite.Release.Refinement.Tel),
    HasTypeVQ P B [] Ψ Q C [] Φ v T → T.fnCore = some t → OldFunctionShape v

theorem old_canonical_statement_false : ¬ OldCanonicalStatement := by
  intro h
  exact concrete_obstruction.2.2
    (h readerProgram B StoreTy.empty Qempty [] [] _ _ _
      concrete_obstruction.1 concrete_obstruction.2.1)

end
end Benitoite.Release.Refinement.CanonicalResumeTrial
