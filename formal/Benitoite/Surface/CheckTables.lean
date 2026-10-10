import Benitoite.Exchange.Builtins
import Benitoite.Surface.Check

/-! 有限の宣言の材料から、実行用の表と判定を同時に作る。 -/
namespace Benitoite.Surface.CheckTables
open Benitoite.Release Benitoite.Surface Benitoite.Surface.CheckTools

/-- 同じ鍵が重なるときは先頭を使う。一覧の外は空欄である。 -/
def lookup (xs : List (String × α)) (name : String) : Option α :=
  (xs.find? (fun x => x.1 == name)).map Prod.snd

theorem lookup_mem {xs : List (String × α)} {name x} (h : lookup xs name = some x) :
    (name, x) ∈ xs := by
  unfold lookup at h
  cases hf : xs.find? (fun y => y.1 == name) with
  | none => simp [hf] at h
  | some y =>
    simp only [hf, Option.map_some, Option.some.injEq] at h
    have hm := List.mem_of_find?_eq_some hf
    have hn := List.find?_some hf
    simp only [beq_iff_eq] at hn
    cases y with
    | mk n v => simp only at hn h; subst n; subst v; exact hm

theorem lookup_none {xs : List (String × α)} {name}
    (h : name ∉ xs.map Prod.fst) : lookup xs name = none := by
  cases he : lookup xs name with
  | none => rfl
  | some x => exact False.elim (h (List.mem_map.mpr ⟨(name,x), lookup_mem he, rfl⟩))

structure PrimEntry where
  name : PrimName
  signature : PrimSig
  constraints : List BuiltinConstraint

/-- admits を同じ材料で束縛し直す。任意の Prop から判定を復元しない。 -/
def primEntries (S : SummaryTable)
    (xs : List (PrimName × Benitoite.Exchange.PrimMaterial)) : List PrimEntry :=
  xs.map fun (name, m) =>
    let cs := m.constraints.map Benitoite.Exchange.PrimConstraint.toBuiltinConstraint
    ⟨name, m.toPrimSig (fun C ts => admitsB S cs C ts = true), cs⟩

def primLookup (xs : List PrimEntry) (name : PrimName) : Option PrimEntry :=
  xs.find? (fun x => x.name == name)

def builtins (S : SummaryTable) (xs : List PrimEntry)
    (b : Benitoite.Exchange.BuiltinInput) : Builtins :=
  { sig := fun n => (primLookup xs n).map PrimEntry.signature
    delta := fun _ _ _ _ => none
    ioResponse := fun _ _ _ _ _ => False
    releaseResponse := fun _ _ => False
    isResource := b.isResource
    effects := b.effectOps
    sat := fun C t p => satB S C t p = true
    refGet := ((b.prims.find? (fun p => p.kind == "refGet")).map (·.name)).getD "Reference.get"
    refSet := ((b.prims.find? (fun p => p.kind == "refSet")).map (·.name)).getD "Reference.set" }

def admitsDec (S : SummaryTable) (xs : List PrimEntry) : AdmitsDec := fun n C ts =>
  match primLookup xs n with
  | none => false
  | some x => admitsB S x.constraints C ts

structure ClassMaterial where
  supers : List ClassName
  methods : List (MethName × MethSig)

def ClassMaterial.decl (c : ClassMaterial) : ClassDecl :=
  ⟨c.supers, lookup c.methods⟩

structure ImplMaterial where
  signature : ImplSig
  supers : List (ClassName × DictEv)
  methods : List (MethName × Block)

def ImplMaterial.decl (i : ImplMaterial) : ImplDecl :=
  { i.signature with supers := lookup i.supers, methods := lookup i.methods }

structure Materials where
  defs : List (FunName × Def)
  accessors : List (FunName × (ConName × Nat))
  data : List Benitoite.Exchange.DataMaterial
  ops : List (OpName × OpDecl)
  effects : List (EffName × List OpName)
  classes : List (ClassName × ClassMaterial)
  impls : List (ImplName × ImplMaterial)
  trustedFuns : List (FunName × FunDecl)
  trustedImpls : List (ImplName × ImplSig)

/-- cons は取得関数に現れないデータ型も含む。 -/
def Materials.program (m : Materials) : Program :=
  { defs := lookup m.defs, cons := Benitoite.Exchange.constructorDecl m.data
    accessors := lookup m.accessors, ops := lookup m.ops, effects := lookup m.effects
    classes := lookup (m.classes.map fun (n,c) => (n,c.decl))
    impls := lookup (m.impls.map fun (n,i) => (n,i.decl)) }

/-- 利用者の宣言を優先し、空欄を信頼するシグネチャで補う。 -/
def extend (D : Declarations) (fs : List (FunName × FunDecl))
    (is : List (ImplName × ImplSig)) : Declarations :=
  { D with funs := fun n => (D.funs n).or (lookup fs n)
           impls := fun n => (D.impls n).or (lookup is n) }

def Materials.declarations (m : Materials) : Declarations :=
  extend m.program.declarations m.trustedFuns m.trustedImpls

def constructorsOk (m : Materials) : Bool :=
  let names := m.data.map (·.name)
  (names.eraseDups.length == names.length) &&
  (m.data.flatMap (·.ctors)).all (fun (n,cd) =>
    (Benitoite.Exchange.dataConstructors m.data cd.data).contains n)

/-- 外部の RecordConDecl は表の材料と照合するだけで cons に上書きしない。 -/
def recordOk (atoms : List Atom) (ds : List Benitoite.Exchange.DataMaterial)
    (name : ConName) (cd : ConDecl) : Bool :=
  match Benitoite.Exchange.constructorDecl ds name with
  | none => false
  | some actual => (actual.data == cd.data) && (actual.ntys == cd.ntys) &&
      tysEq atoms actual.args cd.args

def implNamesOk (m : Materials) (methods supers : List String) : Bool :=
  (m.classes.flatMap fun (_,c) => c.methods.map Prod.fst).all methods.contains &&
  (m.impls.flatMap fun (_,i) => i.methods.map Prod.fst).all methods.contains &&
  (m.impls.flatMap fun (_,i) => i.supers.map Prod.fst).all supers.contains

/-- プログラムの入口が使う有限の一覧。メソッドと上位の名前は空欄も検査する。 -/
structure Names where
  defs : List FunName
  impls : List ImplName
  effects : List EffName
  methods : List MethName
  supers : List ClassName

def Materials.names (m : Materials) : Names :=
  { defs := m.defs.map Prod.fst, impls := m.impls.map Prod.fst
    effects := m.effects.map Prod.fst
    methods := ((m.classes.flatMap fun (_,c) => c.methods.map Prod.fst) ++
      (m.impls.flatMap fun (_,i) => i.methods.map Prod.fst)).eraseDups
    supers := ((m.classes.flatMap fun (_,c) => c.supers) ++
      (m.impls.flatMap fun (_,i) => i.supers.map Prod.fst)).eraseDups }

def Materials.input (m : Materials) (B : Builtins) (sat : SatDec) (admits : AdmitsDec)
    (op : OpPrim) (atoms : List Atom) : Check.Input :=
  ⟨m.declarations, B, sat, admits, op, Benitoite.Exchange.dataConstructors m.data, atoms⟩

/-- 各位置を検査し、最初の失敗の元の経路を返す。 -/
def checkNamed (table : String → Option α) (check : List Nat → α → Check.Result Unit)
    (path : List Nat) : List String → Nat → Check.Result Unit
  | [], _ => .ok ()
  | n :: ns, index => do
    match table n with
    | none => pure ()
    | some x => check (path ++ [index]) x
    checkNamed table check path ns (index + 1)

def checkProgram (q : Check.Input) (p : Program) (names : Names) : Check.Result Unit := do
  checkNamed p.defs (Check.checkDef q) [0] names.defs 0
  checkNamed p.impls (Check.checkImpl q names.methods names.supers) [1] names.impls 0
  -- 操作の並びの値ではなく名前を使って、組み込みの表との重なりを調べる。
  checkNamed (fun n => (p.effects n).map (fun _ => n))
    (fun path n => Check.require path "effect name overlaps a builtin effect" (q.B.effects n).isNone)
    [2] names.effects 0
end Benitoite.Surface.CheckTables
