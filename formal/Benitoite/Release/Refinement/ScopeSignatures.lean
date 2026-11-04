import Benitoite.Release.Refinement.TargetTable
import Benitoite.Release.Refinement.ModelConstraints
import Benitoite.Release.Refinement.ScopeDeclarations
import Benitoite.Release.Refinement.ShapeTargets

/-! # 範囲付きの組込みと参照・起点発行の共通署名 -/
namespace Benitoite.Release.Refinement.ScopeSignatures
open Scope.Domain

abbrev pathIn (i : Nat) : Ty := .opaque "Scope.PathIn" (.rvar i)
abbrev requestIn (i : Nat) : Ty := .opaque "Http.RequestIn" (.rvar i)
abbrev resultTy (a e : Ty) : Ty := .data "Result" [a,e]
abbrev scopeErrorTy : Ty := atErrorType
abbrev requestCheckErrorTy : Ty := .data "Http.RequestCheckError" []
abbrev clientRequestTy : Ty := TargetTable.clientRequestTy

def pureIn (names : List String) (params : List Ty) (ret : Ty) (ks : List Kind) : PrimSig :=
  ⟨[],0,names,params,ret,Eff.empty,(fun _ ts => ts = []),.pure,none,ks,.untargeted⟩

def ioIn (names : List String) (params : List Ty) (ret : Ty) (l : EffName) (k : Kind) : PrimSig :=
  ⟨[],0,names,params,ret,(.mk (fun a => decide (a = .name l (.rvar 0))) []),(fun _ ts => ts = []),.io,
    some l,[k],.single k 0⟩

def readTextIn : PrimSig := ioIn ["path"] [pathIn 0]
  (resultTy (.base .string) (.opaque "IOError" (.fixed .top))) "File.Read" .path
def readBytesIn : PrimSig := ioIn ["path"] [pathIn 0]
  (resultTy .bytes (.opaque "IOError" (.fixed .top))) "File.Read" .path
def writeTextIn : PrimSig := ioIn ["path","text"] [pathIn 0,.base .string]
  (resultTy (.base .unit) (.opaque "IOError" (.fixed .top))) "File.Write" .path
def appendTextIn : PrimSig := ioIn ["path","text"] [pathIn 0,.base .string]
  (resultTy (.base .unit) (.opaque "IOError" (.fixed .top))) "File.Write" .path
def writeBytesIn : PrimSig := ioIn ["path","content"] [pathIn 0,.bytes]
  (resultTy (.base .unit) (.opaque "IOError" (.fixed .top))) "File.Write" .path
def appendBytesIn : PrimSig := ioIn ["path","content"] [pathIn 0,.bytes]
  (resultTy (.base .unit) (.opaque "IOError" (.fixed .top))) "File.Write" .path
def sendIn : PrimSig := ioIn ["request"] [requestIn 0]
  (resultTy (.opaque "Http.Response" (.fixed .top)) (.opaque "NetworkError" (.fixed .top)))
  "Http.Connect" .endpoint

def checkPathIn : PrimSig := pureIn ["pattern","path"] [.base .string,.base .string]
  (resultTy (pathIn 0) scopeErrorTy) [.path]
def checkRequestIn : PrimSig := pureIn ["hostPattern","minimumPort","maximumPort","request"]
  [.base .string,.base .integer,.base .integer,clientRequestTy]
  (resultTy (requestIn 0) requestCheckErrorTy) [.endpoint]
def pathInValue : PrimSig := pureIn ["path"] [pathIn 0] (.base .string) [.path]
def requestInValue : PrimSig := pureIn ["request"] [requestIn 0] clientRequestTy [.endpoint]
def widenPathIn : PrimSig := pureIn ["path"] [pathIn 0] (pathIn 1) [.path,.path]
def widenRequestIn : PrimSig := pureIn ["request"] [requestIn 0] (requestIn 1) [.endpoint,.endpoint]

def refGet : PrimSig :=
  ⟨[TypeCtx.valueParam],0,["reference"],[.reference (.tvar 0)],.tvar 0,Eff.single stateEff,
    (fun _ ts => ts.length = 1),.refGet,none,[],.untargeted⟩
def refSet : PrimSig :=
  ⟨[TypeCtx.valueParam],0,["reference","value"],[.reference (.tvar 0),.tvar 0],.base .unit,
    Eff.single stateEff,(fun _ ts => ts.length = 1),.refSet,none,[],.untargeted⟩

/-- 起点発行の内部の操作名。 -/
def pathBasesName : PrimName := "Example.pathBases"
def pathBases : PrimSig :=
  ⟨[],0,[],[],.pathBases,Eff.single processEnvironmentEff,(fun _ ts => ts = []),.pathBases,
    some processEnvironmentEff,[],.untargeted⟩

def entries : List (PrimName × PrimSig) := [
  ("Reference.get",refGet),("Reference.set",refSet),
  ("File.readTextIn",readTextIn),("File.readBytesIn",readBytesIn),
  ("File.writeTextIn",writeTextIn),("File.appendTextIn",appendTextIn),
  ("File.writeBytesIn",writeBytesIn),("File.appendBytesIn",appendBytesIn),
  ("Http.sendIn",sendIn),("Scope.checkPathIn",checkPathIn),("Http.checkRequestIn",checkRequestIn),
  ("Scope.pathInValue",pathInValue),("Http.requestInValue",requestInValue),
  ("Scope.widenPathIn",widenPathIn),("Http.widenRequestIn",widenRequestIn),(pathBasesName,pathBases)]

def effects : EffName → Option (List PrimName)
  | "State" => some []
  | "File.Read" => some ["File.readTextIn","File.readBytesIn"]
  | "File.Write" => some ["File.writeTextIn","File.appendTextIn","File.writeBytesIn","File.appendBytesIn"]
  | "Http.Connect" => some ["Http.sendIn"]
  | "Process.Environment" => some [pathBasesName]
  | _ => none

def effKind : EffName → Option Kind := Benitoite.Release.TargetTable.effKind

def admitsR : PrimName → List RangeExpr → Prop
  | "Scope.widenPathIn", rs | "Http.widenRequestIn", rs =>
    ∃ r s, rs = [r,s] ∧ s.Covers r
  | b, rs => (b = "File.readTextIn" ∨ b = "File.readBytesIn" ∨ b = "File.writeTextIn" ∨
      b = "File.appendTextIn" ∨ b = "File.writeBytesIn" ∨ b = "File.appendBytesIn" ∨
      b = "Http.sendIn" ∨ b = "Scope.checkPathIn" ∨ b = "Http.checkRequestIn" ∨
      b = "Scope.pathInValue" ∨ b = "Http.requestInValue") ∧ rs.length = 1

/-- 実際の純粋応答・IO応答は同じ署名 lookup に組み合わせる。 -/
def builtins
    (delta : PrimName → List Ty → List Eff → List RangeExpr → List Val → Option Outcome)
    (ioResponse : PrimName → List Ty → List Eff → List Val → Outcome → List Target → Prop) : Builtins where
  sig := fun b => entries.lookup b
  delta := delta
  ioResponse := fun b ts es ws out obs => ∃ sg, entries.lookup b = some sg ∧
    (sg.kind = .io ∨ sg.kind = .exit) ∧ ioResponse b ts es ws out obs
  releaseResponse := fun _ r => r = none
  isResource := fun _ => false
  effects := effects
  sat := ModelConstraints.sat (Benitoite.Release.dataSummaries
    (ScopeDeclarations.http.map StandardKeyTyping.DataDecl.summaryInput))
  refGet := "Reference.get"
  refSet := "Reference.set"
  effKind := effKind
  valKind := TargetTable.valKind
  admitsR := admitsR
  valContent := TargetTable.valContent

/-- lookup の成功を全16行の所属へ戻す。 -/
theorem lookup_mem {α : Type} {xs : List (PrimName × α)} {b : PrimName} {s : α}
    (h : xs.lookup b = some s) : (b,s) ∈ xs := by
  induction xs with
  | nil => simp at h
  | cons x xs ih =>
    rcases x with ⟨n,t⟩
    simp only [List.lookup] at h
    split at h
    · rename_i he; have hn : b = n := by simpa only [beq_iff_eq] using he
      subst n; cases h; exact .head _
    · exact .tail _ (ih h)

example : entries.length = 16 := rfl
example : entries.lookup "File.readTextIn" = some readTextIn ∧
    entries.lookup pathBasesName = some pathBases := ⟨rfl,rfl⟩
/-- 共通表の全 IO 行は、同じ効果リストの所属と対象位置を持つ。 -/
theorem io_op {delta io b sg} (h : (builtins delta io).sig b = some sg)
    (hk : sg.kind = .io ∨ sg.kind = .exit) : (builtins delta io).ShapeOk b sg := by
  have hm := lookup_mem h
  simp only [entries,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at hm
  rcases hm with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals first
    | (simp [refGet,refSet,pureIn,checkPathIn,checkRequestIn,pathInValue,requestInValue,
        widenPathIn,widenRequestIn,pathBases] at hk)
    | (first
        | refine ⟨"File.Read",["File.readTextIn","File.readBytesIn"],rfl,rfl,rfl,by simp,?_⟩
        | refine ⟨"File.Write",["File.writeTextIn","File.appendTextIn","File.writeBytesIn","File.appendBytesIn"],
            rfl,rfl,rfl,by simp,?_⟩
        | refine ⟨"Http.Connect",["Http.sendIn"],rfl,rfl,rfl,by simp,?_⟩)
  all_goals first
    | exact ⟨rfl,rfl,rfl,"Scope.PathIn",rfl,rfl⟩
    | exact ⟨rfl,rfl,rfl,"Http.RequestIn",rfl,rfl⟩

/-- 起点発行は専用の種類に留め、八欄を同じ効果表で満たす。 -/
theorem pathBases_shape {delta io b sg} (h : (builtins delta io).sig b = some sg)
    (hk : sg.kind = .pathBases) : sg.PathBasesShape (builtins delta io) b := by
  have hm := lookup_mem h
  simp only [entries,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at hm
  rcases hm with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals solve
    | (cases hk)
    | exact ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl,[pathBasesName],rfl,by simp⟩

/-- 全登録名は同じ署名表の操作である。 -/
theorem effect_ops {delta io l bs b} (hl : (builtins delta io).effects l = some bs)
    (hb : b ∈ bs) : ∃ sg, (builtins delta io).sig b = some sg ∧
      (sg.kind = .io ∨ sg.kind = .exit ∨ sg.kind = .pathBases) ∧ sg.opEff = some l := by
  change effects l = some bs at hl
  unfold effects at hl
  split at hl <;> cases hl
  all_goals simp only [List.mem_cons,List.not_mem_nil,or_false] at hb
  all_goals rcases hb with rfl | rfl | rfl | rfl
  all_goals exact ⟨_,rfl,by decide,rfl⟩

/-- 起点発行は IO 応答の関係には含めない。 -/
theorem pathBases_no_io {delta io b sg} (h : (builtins delta io).sig b = some sg)
    (hk : sg.kind = .pathBases) (ts es ws out obs) :
    ¬ (builtins delta io).ioResponse b ts es ws out obs := by
  rintro ⟨other,hs,hkind,_⟩
  have he : other = sg := Option.some.inj (hs.symm.trans h)
  subst other
  rw [hk] at hkind
  cases hkind with | inl h => cases h | inr h => cases h

/-- 操作効果を持つ全行の種類を照合する。 -/
theorem opEff_io {delta io b sg l} (h : (builtins delta io).sig b = some sg)
    (hl : sg.opEff = some l) : sg.kind = .io ∨ sg.kind = .exit ∨ sg.kind = .pathBases := by
  have hm := lookup_mem h
  simp only [entries,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at hm
  rcases hm with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals solve | cases hl | decide

example {delta io b sg l} (hs : (builtins delta io).sig b = some sg)
    (hl : sg.opEff = some l) :
    sg.kind = .io ∨ sg.kind = .exit ∨ sg.kind = .pathBases := opEff_io hs hl

example {delta io} : (builtins delta io).effects stateEff = some [] := rfl
example {delta io b sg} (hs : (builtins delta io).sig b = some sg) (hk : sg.kind = .pathBases) :
    sg.PathBasesShape (builtins delta io) b ∧ sg.kind ≠ .io ∧ sg.kind ≠ .exit ∧
      ∀ ts es ws out obs, ¬ (builtins delta io).ioResponse b ts es ws out obs :=
  ⟨pathBases_shape hs hk,by rw [hk]; decide,by rw [hk]; decide,
    fun ts es ws out obs => pathBases_no_io hs hk ts es ws out obs⟩

example {delta io l bs b} (hl : (builtins delta io).effects l = some bs) (hb : b ∈ bs) :
    ∃ sg, (builtins delta io).sig b = some sg ∧
      (sg.kind = .io ∨ sg.kind = .exit ∨ sg.kind = .pathBases) ∧ sg.opEff = some l :=
  effect_ops hl hb

/-- 全ての範囲付き IO は、任意の具体化で同じ対象位置と効果原子を持つ。 -/
example {delta io b sg} (hs : (builtins delta io).sig b = some sg)
    (hk : sg.kind = .io ∨ sg.kind = .exit) (r : RangeExpr) :
    ∃ k l o, sg.shape = .single k 0 ∧ sg.rkinds = [k] ∧ sg.opEff = some l ∧
      (Eff.instR [r] sg.eff).mem (.name l (.fixed r)) ∧
      (sg.params.map (Ty.instR [r]))[0]? = some (.opaque o (.fixed r)) ∧
      (builtins delta io).valKind o = some k := by
  have sh := io_op hs hk
  have hm := lookup_mem hs
  simp only [entries,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at hm
  rcases hm with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals first
    | (cases hk with | inl h => cases h | inr h => cases h)
    | (obtain ⟨l,o,ho,_,he,hp,hv⟩ := sh.single_inst rfl r
       exact ⟨_,l,o,rfl,rfl,ho,he,hp,hv⟩)

/-- 範囲を取らない IO の原署名。対象なしと Top の両方に使う。 -/
def unscopedIO (names : List String) (params : List Ty) (ret : Ty) (l : EffName)
    (shape : Scope.Signature.IOShape) (kind : PrimKind := .io) : PrimSig :=
  ⟨[],0,names,params,ret,Eff.single l,(fun _ ts => ts = []),kind,some l,[],shape⟩

/-- 対象なしと Top の形は、対象の引数や範囲変数を要求しない。 -/
theorem unscopedIO_shape {B : Builtins} {b l names params ret shape kind bs}
    (effects : B.effects l = some bs) (member : b ∈ bs)
    (target : (shape = .untargeted ∧ B.effKind l = none) ∨
      ∃ k, shape = .topTargeted k ∧ B.effKind l = some k) :
    B.ShapeOk b (unscopedIO names params ret l shape kind) := by
  refine ⟨l,bs,rfl,rfl,effects,member,?_⟩
  rcases target with ⟨rfl,h⟩ | ⟨k,rfl,h⟩
  · exact ⟨h,rfl,rfl⟩
  · exact ⟨h,rfl,rfl⟩

private def shapeTable
    (delta : PrimName → List Ty → List Eff → List RangeExpr → List Val → Option Outcome)
    (io : PrimName → List Ty → List Eff → List Val → Outcome → List Target → Prop) : Builtins :=
  { builtins delta io with
    sig := fun b => if b = "print" then some (unscopedIO ["text"] [.base .string] (.base .unit) "Console.Write" .untargeted)
      else if b = "File.readText" then some (unscopedIO ["path"] [.base .string]
        (resultTy (.base .string) (.opaque "IOError" (.fixed .top))) "File.Read" (.topTargeted .path))
      else entries.lookup b
    effects := fun l => if l = "Console.Write" then some ["print"]
      else if l = "File.Read" then some ["File.readText","File.readTextIn","File.readBytesIn"]
      else effects l }

/-- 同じ lookup と効果リストを持つ三形の受理を確かめる。 -/
example {delta io} :
    (∃ sg, (shapeTable delta io).sig "print" = some sg ∧ sg.shape = .untargeted ∧
      (shapeTable delta io).ShapeOk "print" sg) ∧
    (∃ sg, (shapeTable delta io).sig "File.readText" = some sg ∧ sg.shape = .topTargeted .path ∧
      (shapeTable delta io).ShapeOk "File.readText" sg) ∧
    (∃ sg, (shapeTable delta io).sig "File.readTextIn" = some sg ∧ sg.shape = .single .path 0 ∧
      (shapeTable delta io).ShapeOk "File.readTextIn" sg) := by
  refine ⟨⟨_,rfl,rfl,?_⟩,⟨_,rfl,rfl,?_⟩,⟨_,rfl,rfl,?_⟩⟩
  · exact unscopedIO_shape rfl (by simp) (Or.inl ⟨rfl,rfl⟩)
  · exact unscopedIO_shape rfl (by simp) (Or.inr ⟨.path,rfl,rfl⟩)
  · exact ⟨"File.Read",["File.readText","File.readTextIn","File.readBytesIn"],rfl,rfl,rfl,
      by simp,rfl,rfl,rfl,"Scope.PathIn",rfl,rfl⟩
end Benitoite.Release.Refinement.ScopeSignatures
