import Benitoite.Release.BuiltinTable
import Benitoite.Surface.Check

/-! 有限の宣言の材料から、実行用の表と判定を同時に作る。
対応する検査と保証の範囲は設計書 07-04「証明する性質」に従う。
-/
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

/-- 交換形式とは独立した、契約名を必須とする組み込みの材料。 -/
structure PrimMaterial where
  constraints : List BuiltinConstraint
  names : List String
  neffs : Nat
  params : List Ty
  ret : Ty
  eff : Eff
  kind : PrimKind
  opEff : Option EffName

/-- 制約の判定を同じ材料から束縛し、契約名を保つ。 -/
def PrimMaterial.toPrimSig (m : PrimMaterial)
    (admits : List TParam → List Ty → Prop) : PrimSig :=
  { tparams := m.constraints.map (fun c => ⟨c.equality, c.key⟩), neffs := m.neffs,
    names := m.names, params := m.params, ret := m.ret, eff := m.eff,
    admits := admits, kind := m.kind, opEff := m.opEff }

/-- 型の JSON に依存しない組み込みの実行環境の材料。 -/
structure BuiltinMaterial where
  effects : List (EffName × List PrimName)
  resources : List Nat
  refGet : PrimName
  refSet : PrimName

/-- 有限のエフェクト表から操作名を取り出す。 -/
def BuiltinMaterial.effectOps (b : BuiltinMaterial) (name : EffName) : Option (List PrimName) :=
  lookup b.effects name

/-- 不透明な型の名前の先頭にあるリソース識別子を照合する。 -/
def BuiltinMaterial.isResource (b : BuiltinMaterial) (name : OpaqueName) : Bool :=
  match (name.splitOn ":").head?.bind String.toNat? with
  | some id => b.resources.contains id
  | none => false

/-- 構成子の型と列挙を同じ宣言から構築するための材料。 -/
structure DataMaterial where
  name : DataName
  ntys : Nat
  ctors : List (ConName × ConDecl)

/-- データ型の宣言順で構成子を列挙する。 -/
def dataConstructors (ds : List DataMaterial) (name : DataName) : List ConName :=
  ((ds.find? (fun d => d.name == name)).map (fun d => d.ctors.map Prod.fst)).getD []

/-- 構成子の宣言を有限の材料から探索する。 -/
def constructorDecl (ds : List DataMaterial) (name : ConName) : Option ConDecl :=
  lookup (ds.flatMap DataMaterial.ctors) name

structure PrimEntry where
  name : PrimName
  signature : PrimSig
  constraints : List BuiltinConstraint

/-- admits を同じ材料で束縛し直す。任意の Prop から判定を復元しない。 -/
def primEntries (S : SummaryTable)
    (xs : List (PrimName × PrimMaterial)) : List PrimEntry :=
  xs.map fun (name, m) =>
    let cs := m.constraints
    ⟨name, m.toPrimSig (fun C ts => admitsB S cs C ts = true), cs⟩

def primLookup (xs : List PrimEntry) (name : PrimName) : Option PrimEntry :=
  xs.find? (fun x => x.name == name)

def builtins (S : SummaryTable) (xs : List PrimEntry)
    (b : BuiltinMaterial) : Builtins :=
  { sig := fun n => (primLookup xs n).map PrimEntry.signature
    delta := fun _ _ _ _ _ => none
    ioResponse := fun _ _ _ _ _ _ => False
    releaseResponse := fun _ _ => False
    isResource := b.isResource
    effects := b.effectOps
    sat := fun C t p => satB S C t p = true
    refGet := b.refGet
    refSet := b.refSet }

def admitsDec (S : SummaryTable) (xs : List PrimEntry) : AdmitsDec := fun n C ts =>
  match primLookup xs n with
  | none => false
  | some x => admitsB S x.constraints C ts

/-- 演算子に対応する組み込み名だけを選び、型引数は規則から構築する。
交換形式の変換後も同じ入口を使い、型引数の規則を外部の仮定にしない。 -/
def makeOpPrim (select : Operator → Ty → Option PrimName) : OpPrim :=
  fun op ty => (select op ty).map (fun name => (name, op.typeArgs ty))

structure ClassMaterial where
  supers : List ClassName
  methods : List (MethName × MethSig)

def ClassMaterial.decl (c : ClassMaterial) : ClassDecl :=
  ⟨c.supers, lookup c.methods⟩

structure ImplMaterial where
  signature : ImplSig
  supers : List (ClassName × DictEv)
  methods : List (MethName × Check.MethodInput)

/-- 実装メソッドの実名と本体を保持した検査入力を作る。 -/
def ImplMaterial.input (i : ImplMaterial) : Check.ImplInput :=
  { i.signature with supers := lookup i.supers, methods := lookup i.methods }

/-- 型付き表層には検査入力の本体を射影する。 -/
def ImplMaterial.decl (i : ImplMaterial) : ImplDecl := i.input.decl

structure Materials where
  functionViews : FunName → CoverageView := fun _ => closedView
  methodViews : ImplName → MethName → CoverageView := fun _ _ => closedView
  defs : List (FunName × Def)
  conFields : List (ConName × List String)
  accessors : List (FunName × (ConName × Nat))
  data : List DataMaterial
  ops : List (OpName × OpDecl)
  effects : List (EffName × List OpName)
  classes : List (ClassName × ClassMaterial)
  impls : List (ImplName × ImplMaterial)
  trustedFuns : List (FunName × FunDecl)
  trustedImpls : List (ImplName × ImplSig)

/-- cons は取得関数に現れないデータ型も含む。 -/
def Materials.program (m : Materials) : Program :=
  { functionViews := m.functionViews, methodViews := m.methodViews
    defs := lookup m.defs, cons := constructorDecl m.data
    conFields := lookup m.conFields, accessors := lookup m.accessors, ops := lookup m.ops, effects := lookup m.effects
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
    (dataConstructors m.data cd.data).contains n)

/-- 外部の RecordConDecl は表の材料と照合するだけで cons に上書きしない。 -/
def recordOk (atoms : List Atom) (ds : List DataMaterial)
    (name : ConName) (cd : ConDecl) : Bool :=
  match constructorDecl ds name with
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
  -- 交換の材料はまだ範囲の具体化の制約の判定を持たないので、全て Top の列だけを通す（L50.1・L50.2 で交換に加える）。
  ⟨m.declarations, B, sat, admits, op, dataConstructors m.data, atoms, [], fun _ _ => false⟩

/-- 各位置を検査し、最初の失敗の元の経路を返す。 -/
def checkNamed (table : String → Option α) (check : List Nat → α → Check.Result Unit)
    (path : List Nat) : List String → Nat → Check.Result Unit
  | [], _ => .ok ()
  | n :: ns, index => do
    match table n with
    | none => pure ()
    | some x => check (path ++ [index]) x
    checkNamed table check path ns (index + 1)

/-- 元の材料に残したメソッドの実名を含めて本体を検査する。 -/
def checkProgram (q : Check.Input) (m : Materials) (names : Names) : Check.Result Unit :=
  Check.guardResult [] true <| do
    let p := m.program
    checkNamed (fun n => (p.defs n).map (fun d => (n, d)))
      (fun path (n, d) => Check.checkDef { q with D := q.D.withView (p.functionViews n) } path d) [0] names.defs 0
    checkNamed (fun n => (lookup (m.impls.map fun (n,i) => (n,i.input)) n).map (fun id => (n, id)))
      (fun path (n, id) => Check.checkImpl q names.methods names.supers path id (p.methodViews n)) [1] names.impls 0
    -- 操作の並びの値ではなく名前を使って、組み込みの表との重なりを調べる。
    checkNamed (fun n => (p.effects n).map (fun _ => n))
      (fun path n => Check.require path "effect name overlaps a builtin effect" (q.B.effects n).isNone)
      [2] names.effects 0
end Benitoite.Surface.CheckTables
