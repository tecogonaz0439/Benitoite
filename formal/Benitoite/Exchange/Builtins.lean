import Benitoite.Exchange.Convert
import Benitoite.Release.BuiltinTable

/-! 契約名とソース順を保持する独立した交換の入口。
設計書 07-04「証明する性質」の検査対象と既存形式を区別する。 -/
namespace Benitoite.Exchange
open Lean

structure PrimConstraint where
  equality : Bool
  key : Bool
  ordered : Bool
  deriving BEq, ToJson, FromJson

structure BuiltinEntry where
  name : String
  tparams : List PrimConstraint
  neffs : Nat
  names : List String
  params : List Ty
  ret : Ty
  eff : Eff
  kind : String
  opEff : Option String
  classConstraints : List (String × Nat)
  unconvertibleTypes : List String
  deriving ToJson, FromJson

structure DataCtorEntry where
  constructorName : Option String := none
  fields : Option (List String)
  name : String
  args : List Ty
  deriving ToJson, FromJson

structure DataEntry where
  builtin : Benitoite.Exchange.BuiltinData
  package : String
  typeName : String
  isRecord : Bool
  extensible : Bool
  name : String
  ntys : Nat
  ctors : List DataCtorEntry
  deriving ToJson, FromJson

/-- always は「等値でない型（鍵では Float）を型引数によらず含む」である。 -/
structure TypeSummary where
  always : Bool
  dependsOn : List Nat
  deriving BEq, ToJson, FromJson

structure DataSummary where
  name : String
  eq : TypeSummary
  key : TypeSummary
  deriving ToJson, FromJson

structure BuiltinInput where
  group : String
  name : String
  prims : List BuiltinEntry
  effects : List EffectEntry
  resources : List Nat
  dataDecls : List DataEntry
  summaries : List DataSummary
  statePure : List String
  /-- 元の入力が import していない標準ライブラリの宣言。名前は入力の表へ移してある。 -/
  supplementalData : List (String × String)
  supplementalPrims : List String
  deriving ToJson, FromJson

structure BuiltinCorpus where
  version : Nat
  inputs : List BuiltinInput
  deriving ToJson, FromJson

def primKind : String → Except String Benitoite.Release.PrimKind
  | "pure" => pure .pure | "io" => pure .io | "exit" => pure .exit
  | "refNew" => pure .refNew | "refGet" => pure .refGet | "refSet" => pure .refSet
  | "refUpdate" => pure .refUpdate | "force" => pure .force
  | n => throw s!"unknown primitive kind: {n}"

/-- ordered の位置は等値・鍵の制約とともに保持し、admits で検査する。 -/
abbrev PrimMaterial := Benitoite.Surface.CheckTables.PrimMaterial
abbrev DataMaterial := Benitoite.Surface.CheckTables.DataMaterial

/-- opaque の型引数を文字列に埋め込む旧交換形式は、型の置き換えに対応しない。 -/
partial def Ty.hasOpaqueArguments : Ty → Except String Bool
  | .opaque n => do
      let pieces := n.splitOn ":"
      let some id := pieces.head? | throw s!"invalid opaque name: {n}"
      if id.toNat?.isNone then throw s!"invalid opaque type id: {n}"
      let args ← Json.parse (String.intercalate ":" pieces.tail)
      let ts ← (fromJson? args : Except String (List Ty))
      return !ts.isEmpty
  | .data _ ts | .tapp _ ts => do
      return (← ts.mapM Ty.hasOpaqueArguments).any id
  | .fn _ ps r _ => do
      return (← r.hasOpaqueArguments) || (← ps.mapM Ty.hasOpaqueArguments).any id
  | .list t | .reference t | .lazyT t | .set t | .dict _ t => t.hasOpaqueArguments
  | .map k v => do return (← k.hasOpaqueArguments) || (← v.hasOpaqueArguments)
  | _ => pure false

def BuiltinEntry.hasOpaqueArguments (b : BuiltinEntry) : Except String Bool := do
  return (← b.ret.hasOpaqueArguments) || (← b.params.mapM Ty.hasOpaqueArguments).any id

/-- 補った標準ライブラリの型も、同じ入力のデータ型の表を参照していることを確かめる。 -/
partial def Ty.checkDataNames (ds : List DataEntry) : Ty → Except String Unit
  | .data n ts => do
      let some d := ds.find? (fun d => d.name == n) | throw s!"missing data declaration: {n}"
      if d.ntys != ts.length then throw s!"data type arity mismatch: {n}"
      ts.forM (Ty.checkDataNames ds)
  | .ctor (.data n) =>
      if ds.any (fun d => d.name == n) then pure () else throw s!"missing data constructor type: {n}"
  | .tapp _ ts => ts.forM (Ty.checkDataNames ds)
  | .fn _ ps r _ => do ps.forM (Ty.checkDataNames ds); r.checkDataNames ds
  | .list t | .reference t | .lazyT t | .set t | .dict _ t => t.checkDataNames ds
  | .map k v => do k.checkDataNames ds; v.checkDataNames ds
  | _ => pure ()

/-- 対象外の印を信頼して、変換できない型を黙って通さない。 -/
def BuiltinEntry.toMaterial (b : BuiltinEntry) : Except String PrimMaterial := do
  checkNames b.names b.params.length
  if !b.classConstraints.isEmpty then throw s!"typeclass constraints: {b.name}"
  if (← b.hasOpaqueArguments) then throw s!"opaque type arguments: {b.name}"
  return {
    constraints := b.tparams.map (fun c => ⟨c.equality, c.key, c.ordered⟩)
    names := b.names
    neffs := b.neffs
    params := ← b.params.mapM Ty.toRelease
    ret := ← b.ret.toRelease
    eff := b.eff.toRelease
    kind := ← primKind b.kind
    opEff := b.opEff }

def DataEntry.info (d : DataEntry) : DataTypeInfo :=
  ⟨d.builtin, d.package, d.name, d.typeName, d.isRecord, d.extensible⟩

def readBuiltins (j : Json) : Except String BuiltinCorpus := do
  let c : BuiltinCorpus ← fromJson? (← exchangeJson "builtins" j)
  for i in c.inputs do
    validateDataTypes (i.dataDecls.map DataEntry.info)
    for d in i.dataDecls do
      validateBuiltinShape d.builtin d.ntys d.isRecord (d.ctors.map fun c =>
        (c.constructorName.getD "", c.args.map fun t => match t with | .tvar n => some n | _ => none))
      if d.isRecord != d.ctors.any (fun c => c.fields.isSome) ||
          (d.isRecord && d.ctors.length != 1) then throw "data isRecord/fields mismatch"
  return c

def DataEntry.toMaterial (d : DataEntry) : Except String DataMaterial := do
  return { name := d.name, ntys := d.ntys, ctors := ← d.ctors.mapM (fun c => do
    if let some fs := c.fields then checkNames fs c.args.length
    return (c.name, { data := d.name, ntys := d.ntys, args := ← c.args.mapM Ty.toRelease })) }

/-- 宣言順を保存し、網羅性の型からの列挙と Program.cons の材料を同じ表から得る。 -/
def dataConstructors (ds : List DataMaterial) (name : Benitoite.Release.DataName) :
    List Benitoite.Release.ConName :=
  ((ds.find? (fun d => d.name == name)).map (fun d => d.ctors.map Prod.fst)).getD []

def constructorDecl (ds : List DataMaterial) (name : Benitoite.Release.ConName) :
    Option Benitoite.Release.ConDecl :=
  ((ds.flatMap (fun d => d.ctors)).find? (fun c => c.1 == name)).map Prod.snd

def BuiltinInput.toBuiltinMaterial (b : BuiltinInput) : Benitoite.Surface.CheckTables.BuiltinMaterial :=
  ⟨b.effects.map (fun e => (e.name,e.ops)), b.resources,
    ((b.prims.find? (fun p => p.kind == "refGet")).map BuiltinEntry.name).getD "Reference.get",
    ((b.prims.find? (fun p => p.kind == "refSet")).map BuiltinEntry.name).getD "Reference.set"⟩

def BuiltinInput.effectOps (b : BuiltinInput) (name : Benitoite.Release.EffName) :
    Option (List Benitoite.Release.PrimName) :=
  (b.effects.find? (fun e => e.name == name)).map EffectEntry.ops

/-- リソースの識別子を opaque 名の先頭から読む。Task[T] の引数は判定に使わない。 -/
def BuiltinInput.isResource (b : BuiltinInput) (name : Benitoite.Release.OpaqueName) : Bool :=
  match (name.splitOn ":").head?.bind String.toNat? with
  | some id => b.resources.contains id
  | none => false

/-- JSON に依存しない要約の宣言へ、同じ入力の名前のままで移す。 -/
def toBuiltinDataDecl (d : DataMaterial) : Benitoite.Release.BuiltinDataDecl :=
  ⟨d.name, d.ntys, d.ctors.map (fun c => c.2.args)⟩

/-- 書き出した summaries はここでは使わず、宣言の型を変換する。 -/
def BuiltinInput.summaryDecls (b : BuiltinInput) : Except String (List Benitoite.Release.BuiltinDataDecl) := do
  return (← b.dataDecls.mapM DataEntry.toMaterial).map toBuiltinDataDecl

/-- 宣言の検査でも直接使える、Lean で計算した要約の表。 -/
def BuiltinInput.summaryTable (b : BuiltinInput) : Except String Benitoite.Release.SummaryTable := do
  return Benitoite.Release.dataSummaries (← b.summaryDecls)

/-- ordered を失わずに純粋な判定へ渡す。 -/
def PrimConstraint.toBuiltinConstraint (c : PrimConstraint) : Benitoite.Release.BuiltinConstraint :=
  ⟨c.equality, c.key, c.ordered⟩

/-- prim の変換と admits の束縛は、sig を引くたびに繰り返さず一度だけ行う。
対象外の印のある prim は表から除き、それ以外の変換の失敗は返す。 -/
def BuiltinInput.primSignatures (b : BuiltinInput) (S : Benitoite.Release.SummaryTable) :
    Except String (List (Benitoite.Release.PrimName × Benitoite.Release.PrimSig)) := do
  let mut sigs := []
  for p in b.prims do
    if p.unconvertibleTypes.isEmpty && p.classConstraints.isEmpty then
      let m ← p.toMaterial
      let cs := m.constraints
      sigs := sigs ++ [(p.name, m.toPrimSig (fun C ts => Benitoite.Release.admitsB S cs C ts = true))]
  return sigs

/-- 入力ごとの具体的な組み込みの表。宣言の検査では実行の欄を使わない。
Reference.get/set は IO の操作ではないので、使われない入力では sig が none になりうる。 -/
def mkBuiltins (b : BuiltinInput) : Except String Benitoite.Release.Builtins := do
  let S ← b.summaryTable
  let sigs ← b.primSignatures S
  return {
    sig := fun name => (sigs.find? (fun p => p.1 == name)).map Prod.snd
    delta := fun _ _ _ _ => none
    ioResponse := fun _ _ _ _ _ => False
    releaseResponse := fun _ _ => False
    isResource := b.isResource
    effects := b.effectOps
    sat := fun C t p => Benitoite.Release.satB S C t p = true
    refGet := ((b.prims.find? (fun p => p.kind == "refGet")).map BuiltinEntry.name).getD "Reference.get"
    refSet := ((b.prims.find? (fun p => p.kind == "refSet")).map BuiltinEntry.name).getD "Reference.set" }

end Benitoite.Exchange
